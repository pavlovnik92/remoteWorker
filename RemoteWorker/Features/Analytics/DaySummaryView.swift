import SwiftUI

/// A1 · Итог дня. Пуш из истории или экран после «Завершить».
struct DaySummaryView: View {
    let session: WorkSession
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            DaySummaryContent(session: session, showsHeader: true)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .background(Theme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .tint(Theme.accent)
                }
            }
        }
    }
}

/// Содержимое итога дня — встраивается и во вкладку, и в отдельный экран.
struct DaySummaryContent: View {
    let session: WorkSession
    var showsHeader = false

    private var reference: Date { session.endedAt ?? .now }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

            donutCard
            chronologyCard
            metricsRow
            insightCard
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Итог дня")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var subtitle: String {
        if let end = session.endedAt {
            return "\(Format.dayTitle(session.startedAt)) · завершён в \(Format.time(end))"
        }
        return "\(Format.dayTitle(session.startedAt)) · идёт сейчас"
    }

    private var donutCard: some View {
        HStack(spacing: 18) {
            ZStack {
                DonutChart(shares: session.categoryShares, thickness: 22)
                    .frame(width: 148, height: 148)
                VStack(spacing: 2) {
                    Text(Format.hoursMinutes(session.elapsed(asOf: reference)))
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("всего за день")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text2)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(ActivityCategory.allCases) { category in
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(category.color)
                            .frame(width: 10, height: 10)
                        Text(category.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Text(Format.hoursMinutes(session.totalDuration(for: category, asOf: reference)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(18)
        .cardStyle(cornerRadius: 24)
    }

    private var chronologyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ХРОНОЛОГИЯ")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.text2)

            SessionTimelineBar(session: session)

            HStack {
                Text(Format.time(session.startedAt))
                Spacer()
                Text(Format.time(session.startedAt.addingTimeInterval(reference.timeIntervalSince(session.startedAt) / 2)))
                Spacer()
                Text(Format.time(reference))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.text3)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .cardStyle(cornerRadius: 22)
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            MetricCard(value: "\(session.breaksCount)", label: "Перерывов")
            MetricCard(
                value: "\(session.exerciseLogs.count)",
                label: "Разминок",
                valueColor: ActivityCategory.health.color
            )
            MetricCard(value: "\(session.entries.count)", label: "Активностей")
        }
    }

    private var insightCard: some View {
        let insight = makeInsight()
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accent.opacity(0.2))
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: insight.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(insight.text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.text2)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
                )
        )
    }

    /// Ненавязчивые инсайты, без осуждения.
    private func makeInsight() -> (icon: String, title: String, text: String) {
        let logsCount = session.exerciseLogs.count
        let longestWork = session.entries
            .filter { $0.category == .work }
            .map { $0.duration(asOf: reference) }
            .max() ?? 0

        if longestWork >= 2 * 3600 {
            return (
                "flame.fill",
                "Мощный фокус",
                "Самый долгий блок — \(Format.hoursMinutes(longestWork)) подряд. Завтра попробуй прерваться чуть раньше."
            )
        }
        if logsCount >= 3 {
            return (
                "sparkles",
                "Забота о теле",
                "\(Format.plural(logsCount, "разминка", "разминки", "разминок")) за день — тело скажет спасибо."
            )
        }
        if logsCount == 0, !session.entries.isEmpty {
            return (
                "heart",
                "Без разминок",
                "Сегодня без разминок. Завтра попробуй хотя бы одну короткую — шея заметит."
            )
        }
        return (
            "flag.fill",
            "День отмечен",
            "Продолжай отмечать активности — картина дня станет точнее."
        )
    }
}
