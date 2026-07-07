import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Сегодня", systemImage: "timer") {
                TodayView()
            }
            Tab("Разминки", systemImage: "dumbbell") {
                ExercisesTabView()
            }
            Tab("Аналитика", systemImage: "chart.bar") {
                AnalyticsTabView()
            }
        }
        .tint(Theme.accent)
    }
}
