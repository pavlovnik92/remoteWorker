import SwiftData
import SwiftUI

/// S1 · Старт дня: приветствие, донат со вчерашней статистикой, кнопка «Начать день».
struct IdleStartView: View {
    var onStart: () -> Void
    var onSettings: () -> Void

    @AppStorage(AppSettings.userNameKey) private var userName = ""

    @Query(
        filter: #Predicate<WorkSession> { $0.endedAt != nil },
        sort: [SortDescriptor(\WorkSession.startedAt, order: .reverse)]
    )
    private var finishedSessions: [WorkSession]

    private var lastSession: WorkSession? { finishedSessions.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 22) {
                startDonut
                metricsRow
            }
            .padding(.horizontal, 22)

            Spacer()

            Button(action: onStart) {
                Label("Начать день", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(AccentButtonStyle(height: 58))
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            }
            .padding(.trailing, 20)
            .padding(.top, 6)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(userName.isEmpty ? Format.greeting() : "\(Format.greeting()), \(userName)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text2)
            Text("Готов начать день?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(Format.dayTitle(.now))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text3)
                .padding(.top, 1)
        }
    }

    private var startDonut: some View {
        Button(action: onStart) {
            ZStack {
                // Декоративные тонкие кольца вокруг
                Circle().strokeBorder(Theme.separator, lineWidth: 1).frame(width: 262, height: 262)
                Circle().strokeBorder(Theme.separator.opacity(0.6), lineWidth: 1).frame(width: 300, height: 300)

                if let last = lastSession {
                    DonutChart(shares: last.categoryShares, thickness: 20)
                        .frame(width: 218, height: 218)
                    VStack(spacing: 3) {
                        Text(Format.relativeDay(last.startedAt).uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Theme.text2)
                        Text(Format.hoursMinutes(last.elapsed()))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("за рабочий день")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                } else {
                    Circle()
                        .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 20)
                        .frame(width: 218, height: 218)
                    VStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.accent)
                        Text("Начнём?")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("один тап — и день пошёл")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                }
            }
            .frame(width: 300, height: 300)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)

    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            MetricCard(
                value: lastSession.map { Format.hoursMinutes($0.totalDuration(for: .work)) } ?? "—",
                label: "Фокус"
            )
            MetricCard(
                value: lastSession.map { String($0.exerciseLogs.count) } ?? "—",
                label: "Разминок",
                valueColor: ActivityCategory.health.color
            )
            MetricCard(
                value: lastSession.map { String($0.breaksCount) } ?? "—",
                label: "Перерывов"
            )
        }
    }
}
