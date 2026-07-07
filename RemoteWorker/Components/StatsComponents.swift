import SwiftUI

// Переиспользуемые блоки статистики: донат, метрики, хронология.

struct CategoryShare: Identifiable {
    let category: ActivityCategory
    let duration: TimeInterval

    var id: String { category.rawValue }
}

extension WorkSession {
    var categoryShares: [CategoryShare] {
        ActivityCategory.allCases.compactMap { category in
            let duration = totalDuration(for: category, asOf: endedAt ?? .now)
            guard duration > 0 else { return nil }
            return CategoryShare(category: category, duration: duration)
        }
    }
}

struct DonutChart: View {
    let shares: [CategoryShare]
    var thickness: CGFloat = 20

    private struct Segment: Identifiable {
        let id: String
        let color: Color
        let from: Double
        let to: Double
    }

    private var segments: [Segment] {
        let total = shares.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return [] }
        var start: Double = 0
        return shares.map { share in
            let fraction = share.duration / total
            defer { start += fraction }
            return Segment(
                id: share.id,
                color: share.category.color,
                from: start,
                to: start + fraction
            )
        }
    }

    var body: some View {
        ZStack {
            if segments.isEmpty {
                Circle().strokeBorder(Theme.card2, lineWidth: thickness)
            } else {
                ForEach(segments) { segment in
                    Circle()
                        .inset(by: thickness / 2)
                        .trim(from: segment.from, to: segment.to)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: thickness))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    var valueColor: Color = Theme.text

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .cardStyle(cornerRadius: 18)
    }
}

/// Горизонтальная хронология дня: сегменты пропорциональны длительности.
struct SessionTimelineBar: View {
    let session: WorkSession
    var height: CGFloat = 30

    var body: some View {
        let reference = session.endedAt ?? .now
        let entries = session.sortedEntries.filter { $0.duration(asOf: reference) >= 30 }
        let cornerRadius = min(9, height / 2)

        GeometryReader { geo in
            if entries.isEmpty {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.card2)
            } else {
                let total = entries.reduce(0.0) { $0 + $1.duration(asOf: reference) }
                let gaps = CGFloat(entries.count - 1) * 2
                HStack(spacing: 2) {
                    ForEach(entries, id: \.persistentModelID) { entry in
                        Rectangle()
                            .fill(entry.category.color)
                            .frame(width: max(3, (geo.size.width - gaps) * entry.duration(asOf: reference) / total))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .frame(height: height)
    }
}
