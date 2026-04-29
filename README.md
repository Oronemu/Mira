# Mira

> Офлайн AI-дневник для iOS 26+. Ваши мысли остаются на устройстве.

Mira — это дневник с AI-рефлексией, который работает полностью на устройстве. Apple Foundation Models (on-device) по умолчанию, опционально — любой сторонний LLM-провайдер с вашим собственным API-ключом.

## Ключевые возможности

- 📝 Приватные записи: текст, настроение, теги, фотографии.
- 🤖 Еженедельная AI-рефлексия по вашим записям.
- 💬 Ask Mira: запросы к дневнику на естественном языке (RAG поверх локальных эмбеддингов).
- ✍️ Подсказки для письма, когда не знаете, о чём писать.
- 🔒 Блокировка по Face ID, зашифрованная синхронизация iCloud (опционально), нулевая телеметрия содержимого.
- 📆 Календарь-хитмап, аналитика настроения, виджеты для домашнего экрана.

## Технологический стек

- **UI:** SwiftUI (iOS 26+), native-first подход — без MVVM ViewModels
- **State:** `@Observable` state-контейнеры, `@Environment` для DI
- **Модульность:** [Tuist](https://docs.tuist.io) — Swift-модули по фичам
- **Persistence:** SwiftData
- **Конкурентность:** Swift 6 strict, актеры, async/await
- **AI primary:** Remote-провайдеры (Anthropic / OpenAI / OpenRouter) — opt-in, ключ пользователя
- **AI fallback:** Apple Foundation Models framework (on-device)
- **Эмбеддинги:** NaturalLanguage (`NLEmbedding`)
- **Sync:** CloudKit с клиентским шифрованием

## Архитектура

### Модули

Проект разбит на Tuist-модули в двух группах:

- **`Core/`** — инфраструктура без UI: `CoreKit` (контракты и domain-типы), `Utilities`, `Persistence` (SwiftData-репозитории за протоколами), `AIKit` (провайдеры, RAG, промпты), `DesignSystem`, `Telemetry` (Firebase за протоколами `AnalyticsService` / `CrashReporter` и т.д.), `TestSupport`.
- **`Features/`** — отдельный модуль на каждый экран (`EntryList`, `EntryEditor`, `EntryDetail`, `Calendar`, `Insights`, `AskMira`, `Settings`, `Onboarding`). Feature-модули не зависят друг от друга — общаются только через `Core/`.
- **`App/`** — composition root: точка входа, навигация, инжекция сервисов через `@Environment`.
- **`Widgets/`** — WidgetKit-расширение.

Граница `Features/` ↔ `Features/` непроходима — это и есть главный enforcement модульности. Любой обмен данными между фичами идёт через репозитории/сервисы из `Core/`.

### View Model на @Observable, без `@StateObject`

Каждый нетривиальный экран имеет собственный `@MainActor @Observable`-класс — view model экрана. Живёт он во View через `@State`, поэтому SwiftUI сам управляет его жизненным циклом (создаёт при появлении, отпускает при исчезновении). `@ObservableObject` / `@StateObject` / `@ObservedObject` не используются — это устаревшие API под `Combine`, заменённые в iOS 17+ на макрос `@Observable` из фреймворка `Observation`.

```swift
// Features/EntryList/Sources/State/EntryListState.swift
@MainActor
@Observable
public final class EntryListState {
    public var query: EntryQuery { didSet { regroup() } }   // input
    public private(set) var sections: [EntryMonthSection]   // derived output
    public private(set) var isLoading = true
    public private(set) var errorMessage: String?

    private let repository: any EntryRepository

    public init(repository: any EntryRepository, initialQuery: EntryQuery = .all) { … }

    public func observe() async {                            // long-running stream
        for await snapshot in repository.observe(query: .all) { … }
    }

    public func delete(id: UUID) async { … }                 // intent
    public func updateSearchText(_ text: String) { … }
}
```

И его использование во View:

```swift
struct EntryListView: View {
    @Environment(\.entryRepository) private var repository
    @State private var state: EntryListState?

    var body: some View {
        Group { … }
            .task {
                if state == nil { state = EntryListState(repository: repository) }
                await state?.observe()        // SwiftUI cancels on disappear
            }
    }
}
```

Зачем такая дисциплина: input-свойства (`query`) меняются извне, derived (`sections`) — только внутри (`private(set)`); интенты — `async` функции; долгоживущие стримы (`observe`) запускаются из `.task` и автоматически отменяются при уходе с экрана. Тестируется такой класс без UIKit/SwiftUI — конструируешь с моком репозитория и дёргаешь методы.

### Навигация — типизированный NavigationStack

В корне приложения сидит `AppRouter` (`@MainActor @Observable`) с массивом маршрутов:

```swift
// App/Sources/AppRouter.swift
@MainActor
@Observable
final class AppRouter {
    enum Route: Hashable {
        case detail(UUID)
        case editor(EditorMode)
        case dayList(Date)
        case insight(UUID)
    }
    var path: [Route] = []
    func openDetail(_ id: UUID)        { path.append(.detail(id)) }
    func openEditor(_ mode: EditorMode = .new) { path.append(.editor(mode)) }
    func pop()        { _ = path.popLast() }
    func popToRoot()  { path.removeAll() }
}
```

`RootView` биндит `router.path` к `NavigationStack(path:)` и резолвит `Route` через `.navigationDestination(for: Route.self)` в нужные экраны. Coordinator-паттерн не используется — за маршрутизацию отвечает один `@Observable`-объект, прокинутый через `@Environment`. Любой экран может вызвать `router.openDetail(id)` или `router.popToRoot()` без знания о других экранах.

### Dependency Injection через @Environment

`ServiceContainer` (`App/Sources/ServiceContainer.swift`) — composition root. Один раз на старте приложения собирает все долгоживущие сервисы (`SwiftDataEntryRepository`, `AIService`, `SyncService`, Firebase-реализации, `PhotoStorageService` и т.д.) — `live()` для прода, memberwise init для тестов и превью.

Дальше всё инжектится через `@Environment(\.entryRepository)`, `@Environment(\.aiProvider)` и т.д. Каждый ключ — отдельный `EnvironmentKey` в `CoreKit/Sources/Environment/*Key.swift`, а `default` — это `Unimplemented*`-реализация, которая `fatalError`-ит при использовании. Это означает: если забыл прокинуть сервис — упадёшь сразу с понятным сообщением, а не получишь silent broken state.

### Конкурентность

Включён Swift 6 strict concurrency. State-классы и `AppRouter` — `@MainActor`. Репозитории и сервисы — `actor` либо thread-safe реализации (например, `SwiftDataEntryRepository` оборачивает `ModelActor`). Доменные типы (`EntrySnapshot`, `Mood`, `EntryQuery` и пр.) — `Sendable`-структуры, которые можно безопасно гонять между актерами. `Observation` стримы из репозиториев (`AsyncStream<[EntrySnapshot]>`) консьюмятся во View через `.task` — отменяются автоматически.

### Persistence

SwiftData — реализация, не контракт. Все `@Model`-классы (`Entry`, `Insight`, `PhotoAsset`, `AskMiraChat`, `AskMiraTurn`) живут в `Core/Persistence`. Снаружи виден только протокол `EntryRepository` / `InsightRepository` / `AskMiraRepository` из `CoreKit`. Конвертация `@Model` ↔ доменный snapshot — в `Mapping/`. Это значит: SwiftData можно заменить на Core Data или GRDB, не трогая ни одной фичи.

### AI-слой

`AIProvider` — протокол в `CoreKit`. Две реализации в `AIKit`:

- **`RemoteAIProvider`** (primary, opt-in) — Anthropic / OpenAI / OpenRouter. Бэкенды (`AnthropicBackend`, `OpenAIBackend`, `OpenRouterBackend`) реализуют единый `RemoteBackend`-интерфейс, SSE-стриминг разбирается в `Remote/SSE/`. API-ключ хранится в Keychain (`AIKeychain`).
- **`MLXLocalProvider`** (fallback, on-device) — Apple Foundation Models через MLX.

Поверх этого — `AIService`, фасад, который выбирает активного провайдера по настройкам, и `RAGPipeline`, который перед запросом подмешивает к промпту релевантные записи из `VectorIndex` (cosine similarity по локальным `NLEmbedding`-векторам).

## С чего начать

### Требования
- macOS с Xcode 26 (тулчейн Swift 6.2)
- Симулятор iOS 26 (например, iPhone 17 Pro) или устройство на iOS 26+
- [Tuist 4](https://docs.tuist.io) — установка через Homebrew:
  ```bash
  brew install tuist
  ```

### Установка
```bash
git clone <repo-url>
cd Mira

# 1. Подложите свой Firebase-конфиг (см. «Настройка для форков» ниже).
cp App/Resources/GoogleService-Info.plist.example App/Resources/GoogleService-Info.plist
# затем замените placeholder-значения на ключи вашего реального Firebase-проекта.

# 2. Установить внешние SPM-зависимости.
tuist install

# 3. Сгенерировать Xcode workspace из манифестов Project.swift.
tuist generate

# 4. Открыть и запустить.
open Mira.xcworkspace
```

`tuist generate` читает `Tuist.swift`, `Workspace.swift` и все `Project.swift`, чтобы материализовать `Mira.xcworkspace` и `*.xcodeproj` каждого модуля. Сгенерированные артефакты в `.gitignore` — пере-запускайте `tuist generate` после `git pull` или правки манифестов.

### Сборка и тесты из CLI
```bash
tuist build Mira --device "iPhone 17 Pro" --platform iOS
tuist test  --device "iPhone 17 Pro" --platform iOS
```

### Граф зависимостей
```bash
tuist graph
```

### Настройка для форков
Чтобы собрать проект под своим Apple Developer-аккаунтом, замените несколько идентификаторов:

- **Firebase config** — `App/Resources/GoogleService-Info.plist` в `.gitignore`. Создайте проект на [console.firebase.google.com](https://console.firebase.google.com/), скачайте iOS-вариант и положите по этому пути.
- **Bundle identifier** — сейчас `com.veilbytesoft.Mira` в `App/Project.swift`. Поменяйте на свой.
- **iCloud-контейнер и App Group** — `App/Resources/Mira.entitlements` ссылается на `iCloud.com.veilbytesoft.Mira` и `group.com.veilbytesoft.Mira`. Обновите оба под свой bundle ID.
- **Development team** — пропишите `DEVELOPMENT_TEAM` в `App/Project.swift` и `Widgets/Project.swift` (Team ID вашего Apple Developer-аккаунта).

После любого изменения манифестов запускайте `tuist generate` заново.

## Приватность

Mira не собирает, не хранит и не передаёт содержимое дневника на серверы разработчика. Данные остаются на устройстве, кроме случаев когда:
- Вы включили iCloud-синхронизацию (payload зашифрован на клиенте).
- Вы включили Remote AI-провайдера (ваши записи уходят выбранному провайдеру по вашему собственному API-ключу).

Полный текст: [PRIVACY.md](./PRIVACY.md) (English), [PRIVACY.ru.md](./PRIVACY.ru.md) (Русский).

## Лицензия

[MIT](./LICENSE) © Ivan Rovkov
