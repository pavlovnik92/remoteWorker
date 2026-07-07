import Foundation
import SwiftData
import SwiftUI

// Источник истины — записи с таймстемпами в БД.
// «Активная» сессия/активность/пауза = запись без endedAt.

nonisolated enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case work
    case rest
    case health
    case distraction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: "Работа"
        case .rest: "Отдых"
        case .health: "Здоровье"
        case .distraction: "Отвлечение"
        }
    }

    var shortTitle: String {
        switch self {
        case .work: "Работа"
        case .rest: "Отдых"
        case .health: "Здоровье"
        case .distraction: "Отвлеч."
        }
    }

    var color: Color {
        switch self {
        case .work: Color(light: 0x3B79D8, dark: 0x5C93E6)
        case .rest: Color(light: 0xE0913B, dark: 0xE7A555)
        case .health: Color(light: 0x1E8A5B, dark: 0x34B57E)
        case .distraction: Color(light: 0xD8634A, dark: 0xE5775E)
        }
    }
}

nonisolated enum BodyZone: String, Codable, CaseIterable, Identifiable {
    case neck, back, chest, wrists, eyes, legs, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: "Шея"
        case .back: "Спина"
        case .chest: "Грудь и руки"
        case .wrists: "Запястья"
        case .eyes: "Глаза"
        case .legs: "Ноги"
        case .other: "Другое"
        }
    }

    /// Короткое название для чипов-фильтров.
    var chipTitle: String {
        switch self {
        case .chest: "Грудь"
        default: title
        }
    }
}

// MARK: - Сессия

@Model
final class WorkSession {
    var startedAt: Date
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ActivityEntry.session)
    var entries: [ActivityEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \PauseInterval.session)
    var pauses: [PauseInterval] = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog] = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    var isActive: Bool { endedAt == nil }

    var currentPause: PauseInterval? {
        pauses.first { $0.endedAt == nil }
    }

    var isPaused: Bool { currentPause != nil }

    var activeEntry: ActivityEntry? {
        entries.first { $0.endedAt == nil }
    }

    var sortedEntries: [ActivityEntry] {
        entries.sorted { $0.startedAt < $1.startedAt }
    }

    /// Суммарная длительность завершённых пауз.
    var completedPausesDuration: TimeInterval {
        pauses.reduce(0) { acc, p in
            guard let end = p.endedAt else { return acc }
            return acc + end.timeIntervalSince(p.startedAt)
        }
    }

    /// Точка отсчёта для живого таймера: startedAt, сдвинутый на завершённые паузы.
    /// Text(timerInterval: effectiveStart..., pauseTime: currentPause?.startedAt)
    /// даёт корректное «чистое» время без ручного тика.
    var effectiveStart: Date {
        startedAt.addingTimeInterval(completedPausesDuration)
    }

    /// Чистая длительность (без пауз) на момент `date`.
    func elapsed(asOf date: Date = .now) -> TimeInterval {
        let end = endedAt ?? date
        var total = end.timeIntervalSince(startedAt)
        for p in pauses {
            let pEnd = p.endedAt ?? date
            total -= max(0, min(pEnd, end).timeIntervalSince(p.startedAt))
        }
        return max(0, total)
    }

    func totalDuration(for category: ActivityCategory, asOf date: Date = .now) -> TimeInterval {
        entries
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.duration(asOf: date) }
    }

    /// Перерывы = записи отдыха и здоровья.
    var breaksCount: Int {
        entries.filter { $0.category == .rest || $0.category == .health }.count
    }
}

@Model
final class PauseInterval {
    var startedAt: Date
    var endedAt: Date?
    var session: WorkSession?

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }
}

// MARK: - Активности

@Model
final class ActivityTemplate {
    var name: String
    var iconName: String
    var categoryRaw: String
    /// Цвет кружка из палитры S2a; nil — цвет категории.
    var colorHex: Int?
    /// Опциональный лимит «пора заканчивать», в минутах. nil — без лимита.
    var plannedMinutes: Int?
    var sortOrder: Int
    var isBuiltIn: Bool
    /// Служебная роль встроенных шаблонов: "focus", "warmup" — для программного поиска.
    var builtinKind: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ActivityEntry.template)
    var entries: [ActivityEntry] = []

    init(
        name: String,
        iconName: String,
        category: ActivityCategory,
        colorHex: Int? = nil,
        plannedMinutes: Int? = nil,
        sortOrder: Int = 0,
        isBuiltIn: Bool = false,
        builtinKind: String? = nil
    ) {
        self.name = name
        self.iconName = iconName
        self.categoryRaw = category.rawValue
        self.colorHex = colorHex
        self.plannedMinutes = plannedMinutes
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.builtinKind = builtinKind
        self.createdAt = .now
    }

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .work }
        set { categoryRaw = newValue.rawValue }
    }

    var color: Color {
        if let colorHex { return Color(hex: UInt32(colorHex)) }
        return category.color
    }
}

@Model
final class ActivityEntry {
    var startedAt: Date
    var endedAt: Date?
    var template: ActivityTemplate?
    var session: WorkSession?

    // Снапшоты — история переживает правку/удаление шаблона.
    var nameSnapshot: String
    var categoryRaw: String
    var iconSnapshot: String

    init(template: ActivityTemplate, startedAt: Date = .now) {
        self.template = template
        self.startedAt = startedAt
        self.nameSnapshot = template.name
        self.categoryRaw = template.categoryRaw
        self.iconSnapshot = template.iconName
    }

    var category: ActivityCategory {
        ActivityCategory(rawValue: categoryRaw) ?? .work
    }

    var name: String { template?.name ?? nameSnapshot }
    var iconName: String { template?.iconName ?? iconSnapshot }

    func duration(asOf date: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }
}

// MARK: - Разминки

@Model
final class Exercise {
    var name: String
    var zoneRaw: String
    /// Секунды; 0 → упражнение на повторы.
    var durationSeconds: Int
    /// Повторы; 0 → упражнение на время.
    var reps: Int
    var iconName: String
    var details: String
    var steps: [String]
    /// «Выполняю вне приложения» — трекается без таймера.
    var isExternal: Bool
    var isFavorite: Bool
    var isCustom: Bool
    /// Акцентный цвет плитки (nil — зелёный health).
    var accentHex: Int?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    var logs: [ExerciseLog] = []

    init(
        name: String,
        zone: BodyZone,
        durationSeconds: Int = 0,
        reps: Int = 0,
        iconName: String,
        details: String = "",
        steps: [String] = [],
        isExternal: Bool = false,
        isFavorite: Bool = false,
        isCustom: Bool = false,
        accentHex: Int? = nil
    ) {
        self.name = name
        self.zoneRaw = zone.rawValue
        self.durationSeconds = durationSeconds
        self.reps = reps
        self.iconName = iconName
        self.details = details
        self.steps = steps
        self.isExternal = isExternal
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.accentHex = accentHex
        self.createdAt = .now
    }

    var zone: BodyZone {
        get { BodyZone(rawValue: zoneRaw) ?? .other }
        set { zoneRaw = newValue.rawValue }
    }

    var accentColor: Color {
        if let accentHex { return Color(hex: UInt32(accentHex)) }
        return ActivityCategory.health.color
    }

    /// «2 мин» / «15 повторов»
    var dosageText: String {
        if reps > 0 { return "\(reps) повторов" }
        let m = max(1, durationSeconds / 60)
        return "\(m) мин"
    }
}

@Model
final class ExerciseLog {
    var completedAt: Date
    var exercise: Exercise?
    var nameSnapshot: String
    var session: WorkSession?

    init(exercise: Exercise, session: WorkSession?, completedAt: Date = .now) {
        self.exercise = exercise
        self.nameSnapshot = exercise.name
        self.session = session
        self.completedAt = completedAt
    }
}
