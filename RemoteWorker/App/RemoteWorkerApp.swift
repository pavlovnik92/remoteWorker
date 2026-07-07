import SwiftData
import SwiftUI
import UserNotifications

@main
struct RemoteWorkerApp: App {
    @AppStorage(AppSettings.themeKey) private var themeRaw = AppTheme.system.rawValue
    @State private var breakCenter = BreakCenter()

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: WorkSession.self,
                PauseInterval.self,
                ActivityTemplate.self,
                ActivityEntry.self,
                Exercise.self,
                ExerciseLog.self
            )
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(breakCenter)
                .preferredColorScheme((AppTheme(rawValue: themeRaw) ?? .system).colorScheme)
                .task { SeedData.seedIfNeeded(context: container.mainContext) }
        }
        .modelContainer(container)
    }
}
