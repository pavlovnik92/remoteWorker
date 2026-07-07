import SwiftUI

/// A2 · Неделя: бары по дням, средний фокус, стрик разминок, баланс категорий.
struct WeekStatsContent: View {
    let sessions: [WorkSession]

    private struct DayStat: Identifiable {
        let date: Date
        let total: TimeInterval
        let work: TimeInterval
        let rest: TimeInterval
        let health: TimeInterval
        let exerciseCount: Int
        var id: Date { date }
    }

    private var days: [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let daySessions = sessions.filter { cal.isDate($0.startedAt, inSameDayAs: day) }
            return DayStat(
                date: day,
                total: daySessions.reduce(0) { $0 + $1.elapsed(asOf: $1.endedAt ?? .now) },
                work: daySessions.reduce(0) { $0 + $1.totalDuration(for: .work, asOf: $1.endedAt ?? .now) },
                rest: daySessions.reduce(0) { $0 + $1.totalDuration(for: .rest, asOf: $1.endedAt ?? .now) },
                health: daySessions.reduce(0) { $0 + $1.totalDuration(for: .health, asOf: $1.endedAt ?? .now) },
                exerciseCount: daySessions.reduce(0) { $0 + $1.exerciseLogs.count }
            )
        }
    }

    var body: some View {
        let stats = days

        VStack(spacing: 14) {
            barsCard(stats)

            HStack(spacing: 10) {
                averageFocusCard(stats)
                streakCard(stats)
            }

            balanceCard(stats)
        }
    }

    // MARK: - Бары по дням

    private func barsCard(_ stats: [DayStat]) -> some View {
        let maxTotal = max(1, stats.map(\.total).max() ?? 1)
        let cal = Calendar.current

        return VStack(alignment: .leading, spacing: 14) {
            Text("ПОСЛЕДНИЕ 7 ДНЕЙ")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.text2)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats) { day in
                    let isToday = cal.isDateInToday(day.date)
                    VStack(spacing: 7) {
                        Text(day.total > 0 ? Format.hoursMinutes(day.total) : " ")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Capsule()
                            .fill(isToday ? Theme.accent : Theme.accent.opacity(0.22))
                            .frame(height: max(6, CGFloat(day.total / maxTotal) * 120))
                        Text(weekdayLetter(day.date))
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? Theme.accent : Theme.text3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 165, alignment: .bottom)
        }
        .padding(18)
        .cardStyle(cornerRadius: 22)
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Format.locale
        f.dateFormat = "EE"
        return f.string(from: date).capitalized
    }

    // MARK: - Метрики

    private func averageFocusCard(_ stats: [DayStat]) -> some View {
        let daysWithWork = stats.filter { $0.work > 0 }
        let avg = daysWithWork.isEmpty
            ? 0
            : daysWithWork.reduce(0) { $0 + $1.work } / Double(daysWithWork.count)

        return VStack(alignment: .leading, spacing: 4) {
            Text(avg > 0 ? Format.hoursMinutes(avg) : "—")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("средний фокус в день")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private func streakCard(_ stats: [DayStat]) -> some View {
        var streak = 0
        for day in stats.reversed() {
            if day.exerciseCount > 0 {
                streak += 1
            } else if Calendar.current.isDateInToday(day.date) {
                continue // сегодня ещё не вечер
            } else {
                break
            }
        }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(ActivityCategory.rest.color)
                Text("\(streak)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
            Text("стрик дней с разминкой")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    // MARK: - Баланс категорий

    private func balanceCard(_ stats: [DayStat]) -> some View {
        let work = stats.reduce(0) { $0 + $1.work }
        let rest = stats.reduce(0) { $0 + $1.rest }
        let health = stats.reduce(0) { $0 + $1.health }
        let total = max(1, work + rest + health)

        return VStack(alignment: .leading, spacing: 12) {
            Text("БАЛАНС НЕДЕЛИ")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.text2)

            balanceRow(category: .work, value: work, fraction: work / total)
            balanceRow(category: .rest, value: rest, fraction: rest / total)
            balanceRow(category: .health, value: health, fraction: health / total)
        }
        .padding(18)
        .cardStyle(cornerRadius: 22)
    }

    private func balanceRow(category: ActivityCategory, value: TimeInterval, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(value > 0 ? Format.hoursMinutes(value) : "—")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.card2)
                    Capsule()
                        .fill(category.color)
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
        }
    }
}
