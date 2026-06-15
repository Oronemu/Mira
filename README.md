# Mira

> Офлайн AI-дневник для iOS 26+. Ваши мысли остаются на устройстве.

Mira — это дневник с AI-рефлексией, который по умолчанию работает полностью на устройстве: локальные модели **Qwen 3** через MLX, без отправки записей куда-либо. Опционально — облачный AI по подписке **Mira Pro** (через серверы Mira, свой API-ключ не нужен) или прямой remote-провайдер с вашим собственным ключом.

## Ключевые возможности

- 📝 Приватные записи: текст, настроение, теги, фотографии, кастомные стикеры.
- 🤖 Еженедельная AI-рефлексия по вашим записям — на устройстве или в облаке (Pro).
- 💬 Ask Mira: запросы к дневнику на естественном языке (RAG поверх локальных эмбеддингов).
- 📆 Календарь-хитмап, аналитика настроения, статистика, виджеты (включая Lock Screen).
- 🔒 Блокировка по Face ID, зашифрованная синхронизация iCloud (опционально), нулевая телеметрия содержимого.
- ⭐️ **Mira Pro** — облачный AI, расширенная статистика, темы, цели и привычки и другое (см. ниже).

## Технологический стек

- **UI:** SwiftUI (iOS 26+), native-first подход — без MVVM ViewModels
- **State:** `@Observable` state-контейнеры, `@Environment` для DI
- **Модульность:** [Tuist](https://docs.tuist.io) — Swift-модули по фичам
- **Persistence:** SwiftData
- **Конкурентность:** Swift 6 strict, актеры, async/await
- **AI on-device (по умолчанию):** локальные модели Qwen 3 (4-bit) через MLX ([`mlx-swift-examples`](https://github.com/ml-explore/mlx-swift-examples))
- **AI hosted (Mira Pro):** прокси через Cloudflare Worker к Anthropic Claude (свой ключ не нужен)
- **AI remote (opt-in):** Anthropic / OpenAI / OpenRouter с вашим собственным API-ключом
- **Эмбеддинги:** NaturalLanguage (`NLEmbedding`)
- **Подписки:** StoreKit 2
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

`AIProvider` — протокол в `CoreKit`. Реализации в `AIKit`:

- **`MLXLocalProvider`** (on-device, по умолчанию) — локальный inference через [MLX](https://github.com/ml-explore/mlx-swift-examples) (пакет `mlx-swift-examples`, продукты `MLXLLM` / `MLXLMCommon`; токенизация — `swift-transformers` от HuggingFace). Гоняет квантованные (4-bit) модели семейства **Qwen 3**, скачиваемые по запросу с HuggingFace Hub:
  - **Qwen 3 4B** — `mlx-community/Qwen3-4B-Instruct-2507-4bit`, ≈2.3 ГБ, минимум 8 ГБ RAM (модель по умолчанию).
  - **Qwen 3 8B** — `lmstudio-community/Qwen3-8B-MLX-4bit`, ≈4.6 ГБ, минимум 12 ГБ RAM (более глубокие рефлексии).

  Каталог — `AIKit/Local/LocalModelCatalog.swift`; выбор и загрузка модели — в Settings. Никакого Apple Foundation Models: текст генерируется открытыми моделями целиком на устройстве.
- **`HostedAIProvider`** (Mira Pro) — проксирует запросы через Cloudflare Worker Mira к Anthropic Claude. Воркер аутентифицирует устройство по StoreKit JWS, держит ключ Claude у себя и применяет помесячные лимиты per-intent (Ask Mira, авто/ручная еженедельная рефлексия). См. `AIKit/Hosted/`.
- **`RemoteAIProvider`** (opt-in, свой ключ) — Anthropic / OpenAI / OpenRouter напрямую. Бэкенды (`AnthropicBackend`, `OpenAIBackend`, `OpenRouterBackend`) реализуют единый `RemoteBackend`-интерфейс, SSE-стриминг разбирается в `Remote/SSE/`. API-ключ хранится в Keychain (`AIKeychain`).
- **`NoAIProvider`** — заглушка, когда AI выключен.

`AIProviderFactory` выбирает провайдера для каждого вызова: есть подтверждённая Pro-подписка → `HostedAIProvider`, иначе — локальная/remote реализация, собранная `AIService` по настройкам. Поверх — `RAGPipeline`, который перед запросом подмешивает к промпту релевантные записи из `VectorIndex` (cosine similarity по локальным `NLEmbedding`-векторам).

## Mira Pro (подписка)

Бесплатно работает весь офлайн-опыт: записи, локальная AI-рефлексия и Ask Mira на моделях Qwen 3, календарь, базовая аналитика, Face ID, виджеты, экспорт в Markdown, iCloud-синхронизация.

**Mira Pro** (StoreKit 2) добавляет облачный AI и продвинутые фичи. Каждая Pro-возможность — отдельный кейс в `ProEntitlement` (`Core/CoreKit/Sources/Domain/ProEntitlement.swift`), гейтинг — через `SubscriptionService.isEntitled(to:)`:

- **Hosted Cloud AI** — Ask Mira и рефлексии через серверы Mira, без своего API-ключа. Лимиты per-intent: Ask Mira ≈100/мес, ручные еженедельные рефлексии ≈2/мес (авто-рефлексии из фонового таска не тарифицируются). Остаток виден в Settings (`UsageSnapshot`, эндпоинт воркера `/v1/usage`).
- **Расширенная статистика** — корреляции тегов, прогнозы, year-in-review.
- **Кастомные AI-персоны** — собственный «голос» Mira.
- **Цели и привычки** на основе тегов.
- **Умные сохранённые фильтры.**
- **Темы и альтернативные иконки приложения.**
- **PDF-экспорт с шаблонами.**
- **Дополнительные виджеты** (включая Lock Screen).
- **Импортёры** (Day One / Apple Notes / Markdown).
- **Кастомные стикеры** — удаление фона на устройстве.

Планы: помесячный (`com.veilbytesoft.Mira.pro.monthly`, $5.99, 7-дневный бесплатный триал) и годовой (`com.veilbytesoft.Mira.pro.yearly`, $49.99 — дешевле в пересчёте на месяц). Поддерживаются восстановление покупок и redeem-коды (внеап-гранты через эндпоинт воркера `/v1/redeem`). Конфиг продуктов — `App/Resources/Mira.storekit`.

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

По умолчанию содержимое дневника не покидает устройство. Данные остаются на устройстве, кроме случаев когда:
- Вы включили iCloud-синхронизацию (payload зашифрован на клиенте).
- Вы оформили **Mira Pro** и пользуетесь облачным AI (Ask Mira / рефлексии): текст соответствующих записей и промпт уходят на Cloudflare Worker Mira и далее в Anthropic Claude для генерации ответа. Воркер не хранит тело запроса; Anthropic не обучается на запросах commercial API.
- Вы включили **Remote AI** со своим ключом: записи уходят выбранному провайдеру по вашему собственному API-ключу.

Usage-телеметрия (Firebase Analytics / Crashlytics / Messaging / Remote Config) фиксирует только факты использования — какие экраны открыты, какие фичи задействованы, счётчики — и **никогда** содержимое записей, эмбеддинги, фото или AI-промпты.

Полный текст: [PRIVACY.md](./PRIVACY.md) (English), [PRIVACY.ru.md](./PRIVACY.ru.md) (Русский).

## Лицензия

[MIT](./LICENSE) © Ivan Rovkov
