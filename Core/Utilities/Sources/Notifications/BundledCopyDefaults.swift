import Foundation

/// In-code fallback texts for local notifications. Used when Remote Config
/// has no override for the requested (kind, language) tuple. EN serves as
/// the universal fallback for unsupported languages.
enum BundledCopyDefaults {
    static func items(for kind: LocalNotificationKind, language: String) -> [NotificationCopy] {
        let table: [String: [NotificationCopy]]
        switch kind {
        case .eveningReflection: table = evening
        case .inactivity: table = inactivity
        }
        return table[language] ?? table["en"] ?? []
    }

    private static let evening: [String: [NotificationCopy]] = [
        "en": [
            .init(title: "Quick one", body: "Quick brain dump? 5 lines max, promise."),
            .init(title: "Plot recap 🎬", body: "What was today's plot twist?"),
            .init(title: "Spill it", body: "One nice thing happened today. Tell me."),
            .init(title: "Vibe check 🌙", body: "Today on a scale of 🥲 to 🌈 — and why?"),
            .init(title: "Soundtrack? 🎧", body: "If today had a soundtrack, what's the vibe?"),
            .init(title: "Brain dump", body: "Anything bugging you? Better out than in."),
            .init(title: "LOL meter 😄", body: "What made you laugh today?"),
            .init(title: "Brag corner", body: "Tiny win to brag about? Brag away."),
            .init(title: "Tea and thoughts 🍵", body: "What deserves a little gratitude tonight?"),
            .init(title: "Future-you's calling", body: "Future-you wants to read this. Don't ghost."),
        ],
        "ru": [
            .init(title: "Быстренько", body: "Скинь пару мыслей, ну? 5 строк хватит."),
            .init(title: "Краткий пересказ 🎬", body: "Какой сегодня был сюжетный поворот?"),
            .init(title: "Колись", body: "Что-то приятное случилось — давай, рассказывай."),
            .init(title: "Vibe check 🌙", body: "Сегодня по шкале от 🥲 до 🌈 — где? И почему?"),
            .init(title: "Саундтрек? 🎧", body: "Если бы у дня был саундтрек — какой вайб?"),
            .init(title: "Выгрузи мысли", body: "Что-то напрягает? Лучше выложить."),
            .init(title: "Смехометр 😄", body: "Что сегодня тебя рассмешило?"),
            .init(title: "Уголок хвастовства", body: "Маленькая победа? Хвастайся."),
            .init(title: "Чай и мысли 🍵", body: "Что заслуживает пары слов благодарности?"),
            .init(title: "Будущий ты звонит", body: "Будущий ты хочет это прочитать. Не игнорь."),
        ],
    ]

    private static let inactivity: [String: [NotificationCopy]] = [
        "en": [
            .init(title: "Long time", body: "Hey, it's been a minute. How's life?"),
            .init(title: "You up? 👻", body: "You've been ghosting me. Everything cool?"),
            .init(title: "Plot update? 📖", body: "Plot's been quiet. Wanna catch me up?"),
            .init(title: "Still here", body: "Just hanging around, waiting. Tell me something."),
            .init(title: "Knock knock", body: "A couple sentences, that's all. Whenever you're ready."),
        ],
        "ru": [
            .init(title: "Давно не виделись", body: "Эй, тебя не было. Как жизнь?"),
            .init(title: "Ты тут? 👻", body: "Ты меня игноришь. Всё ок?"),
            .init(title: "Апдейт сюжета? 📖", body: "У нас тихо в сюжете. Расскажешь?"),
            .init(title: "Всё ещё жду", body: "Сижу, жду. Расскажи что-нибудь."),
            .init(title: "Тук-тук", body: "Пара предложений — и всё. Когда будет настроение."),
        ],
    ]
}
