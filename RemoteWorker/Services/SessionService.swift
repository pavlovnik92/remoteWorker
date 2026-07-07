import Foundation
import SwiftData

/// Операции над сессией. Вся истина — в БД; сервис только пишет таймстемпы.
enum SessionService {
    static func activeSession(in context: ModelContext) -> WorkSession? {
        var descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func latestFinishedSession(in context: ModelContext) -> WorkSession? {
        var descriptor = FetchDescriptor<WorkSession>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    static func startDay(context: ModelContext) -> WorkSession {
        if let existing = activeSession(in: context) { return existing }
        let session = WorkSession()
        context.insert(session)
        try? context.save()
        return session
    }

    static func pause(_ session: WorkSession, context: ModelContext) {
        guard session.isActive, !session.isPaused else { return }
        session.activeEntry?.endedAt = .now
        let pause = PauseInterval()
        context.insert(pause)
        pause.session = session
        try? context.save()
    }

    static func resume(_ session: WorkSession, context: ModelContext) {
        session.currentPause?.endedAt = .now
        try? context.save()
    }

    static func finish(_ session: WorkSession, context: ModelContext) {
        let now = Date.now
        session.activeEntry?.endedAt = now
        session.currentPause?.endedAt = now
        session.endedAt = now
        try? context.save()
    }

    /// Тап по кружку: та же активность — стоп, другая — переключение.
    /// Возвращает новую активную запись (nil, если активность выключили).
    @discardableResult
    static func toggleActivity(
        _ template: ActivityTemplate,
        in session: WorkSession,
        context: ModelContext
    ) -> ActivityEntry? {
        let now = Date.now
        if let active = session.activeEntry {
            let same = active.template?.persistentModelID == template.persistentModelID
            active.endedAt = now
            if same {
                try? context.save()
                return nil
            }
        }
        let entry = ActivityEntry(template: template, startedAt: now)
        context.insert(entry)
        entry.session = session
        try? context.save()
        return entry
    }

    /// Встроенный шаблон «Разминка» — в него переключается сессия при старте упражнения.
    static func warmupTemplate(in context: ModelContext) -> ActivityTemplate? {
        let kind = "warmup"
        var descriptor = FetchDescriptor<ActivityTemplate>(
            predicate: #Predicate { $0.builtinKind == kind }
        )
        descriptor.fetchLimit = 1
        if let found = (try? context.fetch(descriptor))?.first { return found }
        // Запасной вариант — любой шаблон категории «Здоровье».
        let health = ActivityCategory.health.rawValue
        var fallback = FetchDescriptor<ActivityTemplate>(
            predicate: #Predicate { $0.categoryRaw == health }
        )
        fallback.fetchLimit = 1
        return (try? context.fetch(fallback))?.first
    }
}
