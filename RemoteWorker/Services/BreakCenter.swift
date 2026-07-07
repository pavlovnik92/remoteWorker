import Foundation
import Observation
import UserNotifications

/// Центр перерывов: считает, когда пора размяться, показывает внутренний шит
/// (форграунд) и планирует локальный пуш (бэкграунд). Уважает тихие часы.
@Observable
final class BreakCenter {
    static let notificationID = "break.reminder"
    static let limitNotificationID = "activity.limit"
    private static let nextPromptKey = "break.nextPromptAt"

    /// Управляет показом BreakSheet.
    var promptVisible = false

    var nextPromptAt: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: Self.nextPromptKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.nextPromptKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.nextPromptKey)
            }
        }
    }

    private var interval: TimeInterval {
        TimeInterval(AppSettings.breakIntervalMinutes * 60)
    }

    // MARK: - События сессии

    /// Началась рабочая активность. Если это продолжение рабочей цепочки
    /// (переключение Фокус → Созвон), отсчёт не сбрасывается.
    func workStarted(at date: Date, continuingWorkChain: Bool) {
        if continuingWorkChain, nextPromptAt != nil {
            rescheduleNotification()
            return
        }
        nextPromptAt = date.addingTimeInterval(interval)
        rescheduleNotification()
    }

    /// Активность не рабочая (отдых/здоровье/выключено/пауза/финиш) — отсчёт не нужен.
    func cancelCountdown() {
        promptVisible = false
        nextPromptAt = nil
        removePendingNotification()
    }

    func snooze(minutes: Int = 10) {
        promptVisible = false
        nextPromptAt = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        rescheduleNotification()
    }

    func skip() {
        promptVisible = false
        nextPromptAt = Date.now.addingTimeInterval(interval)
        rescheduleNotification()
    }

    /// Шит закрыли свайпом без выбора действия — считаем как «пропустить»,
    /// иначе периодическая проверка тут же покажет его снова.
    func promptDismissed() {
        promptVisible = false
        if let due = nextPromptAt, due <= .now {
            skip()
        }
    }

    func exerciseCompleted(stillInSession: Bool) {
        promptVisible = false
        if stillInSession {
            nextPromptAt = Date.now.addingTimeInterval(interval)
            rescheduleNotification()
        } else {
            cancelCountdown()
        }
    }

    /// Периодическая проверка из вью активной сессии.
    func checkPrompt(session: WorkSession?) {
        guard
            let session,
            session.isActive,
            !session.isPaused,
            let entry = session.activeEntry,
            entry.category == .work,
            let due = nextPromptAt,
            Date.now >= due,
            !promptVisible,
            !AppSettings.isQuietTime(.now)
        else { return }
        promptVisible = true
    }

    /// Сколько минут длится текущая рабочая активность (для текстов шита/подсказки).
    func workStreakMinutes(session: WorkSession?, asOf date: Date = .now) -> Int {
        guard
            let entry = session?.activeEntry,
            entry.category == .work
        else { return 0 }
        return Int(entry.duration(asOf: date) / 60)
    }

    // MARK: - Лимит активности («пора заканчивать»)

    /// Началась новая активность: если у её шаблона задан лимит —
    /// планируем пуш на момент его истечения, иначе снимаем старый.
    func activityStarted(_ entry: ActivityEntry) {
        guard
            let minutes = entry.template?.plannedMinutes,
            minutes > 0
        else {
            cancelActivityLimit()
            return
        }
        let deadline = entry.startedAt.addingTimeInterval(TimeInterval(minutes * 60))
        scheduleActivityLimit(name: entry.name, minutes: minutes, at: deadline)
    }

    func cancelActivityLimit() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.limitNotificationID])
    }

    private func scheduleActivityLimit(name: String, minutes: Int, at deadline: Date) {
        cancelActivityLimit()
        guard
            AppSettings.notificationsEnabled,
            deadline > .now,
            !AppSettings.isQuietTime(deadline)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Пора закругляться"
        content.body = "«\(name)» длится уже \(minutes) мин — время переключиться."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.limitNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, deadline.timeIntervalSinceNow),
                repeats: false
            )
        )
        let center = UNUserNotificationCenter.current()
        Task { try? await center.add(request) }
    }

    // MARK: - Уведомления

    func ensureAuthorization() async {
        guard AppSettings.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    private func removePendingNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func rescheduleNotification() {
        removePendingNotification()
        guard
            AppSettings.notificationsEnabled,
            let fireDate = nextPromptAt,
            fireDate > .now,
            !AppSettings.isQuietTime(fireDate)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Пора размяться"
        content.body = "Вы в фокусе уже \(AppSettings.breakIntervalMinutes) минут — спина скажет спасибо."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: trigger
        )
        let center = UNUserNotificationCenter.current()
        Task { try? await center.add(request) }
    }
}

/// В форграунде баннер не показываем — вместо него внутренний шит S3.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
