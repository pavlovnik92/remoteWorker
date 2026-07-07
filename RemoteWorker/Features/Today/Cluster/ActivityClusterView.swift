import SwiftData
import SwiftUI

/// Кластер кружков-активностей. Размер кружка = f(дефицит внимания):
/// v1-эвристика по README (полный алгоритм — S2_algorithm_brief, в пакете отсутствует):
///  - активная активность → Hero с кольцом прогресса;
///  - «Отвлечение» жёстко капается классом S и приглушается;
///  - при длинном фокусе подрастают Здоровье и самый «забытый» Отдых (не более двух L);
///  - остальные — M, хвост за пределами первых семи — S.
struct ActivityClusterView: View {
    let session: WorkSession
    let templates: [ActivityTemplate]
    let now: Date
    let breakIntervalMinutes: Int
    var onTap: (ActivityTemplate) -> Void
    var onEdit: (ActivityTemplate) -> Void
    var onDelete: (ActivityTemplate) -> Void
    var onAdd: () -> Void

    private var activeEntry: ActivityEntry? { session.activeEntry }

    private var activeTemplateID: PersistentIdentifier? {
        activeEntry?.template?.persistentModelID
    }

    var body: some View {
        GeometryReader { geo in
            let sizes = computeSizes()
            let layout = computeLayout(sizes: sizes, in: geo.size)
            let signature = layoutSignature(sizes: sizes)

            ZStack {
                ForEach(templates, id: \.persistentModelID) { template in
                    let id = ClusterID.template(template.persistentModelID)
                    let sizeClass = sizes[template.persistentModelID] ?? .m
                    circleView(template, sizeClass: sizeClass)
                        .position(layout[id] ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                }

                AddCircleView(action: onAdd)
                    .position(layout[.add] ?? CGPoint(x: geo.size.width - 40, y: geo.size.height - 40))
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.8), value: signature)
        }
    }

    // MARK: - Размеры

    private func computeSizes() -> [PersistentIdentifier: CircleSizeClass] {
        var result: [PersistentIdentifier: CircleSizeClass] = [:]
        let streakMinutes = workStreakMinutes()
        let growThreshold = Int(Double(breakIntervalMinutes) * 0.6)
        let strongThreshold = Int(Double(breakIntervalMinutes) * 0.8)

        let nonHero = templates.filter { $0.persistentModelID != activeTemplateID }

        // Кандидаты на рост при дефиците отдыха.
        var grown: Set<PersistentIdentifier> = []
        if streakMinutes >= growThreshold {
            if let health = nonHero
                .filter({ $0.category == .health })
                .min(by: { lastUse($0) < lastUse($1) }) {
                grown.insert(health.persistentModelID)
            }
            if streakMinutes >= strongThreshold {
                if let rest = nonHero
                    .filter({ $0.category == .rest })
                    .min(by: { lastUse($0) < lastUse($1) }),
                    grown.count < 2 {
                    grown.insert(rest.persistentModelID)
                }
            }
        }

        for (index, template) in templates.enumerated() {
            let id = template.persistentModelID
            if id == activeTemplateID {
                result[id] = .hero
            } else if template.category == .distraction {
                result[id] = .s // никогда не растёт
            } else if grown.contains(id) {
                result[id] = .l
            } else if index >= 7 {
                result[id] = .s // хвост длинного списка
            } else {
                result[id] = .m
            }
        }
        return result
    }

    /// Кружки, выросшие по рекомендации — им рисуем бейдж sparkles.
    private func grownIDs(sizes: [PersistentIdentifier: CircleSizeClass]) -> Set<PersistentIdentifier> {
        Set(sizes.filter { $0.value == .l }.keys)
    }

    private func workStreakMinutes() -> Int {
        guard let entry = activeEntry, entry.category == .work else { return 0 }
        return Int(entry.duration(asOf: now) / 60)
    }

    /// Когда активность использовалась в последний раз в этой сессии.
    private func lastUse(_ template: ActivityTemplate) -> Date {
        let inSession = session.entries.filter {
            $0.template?.persistentModelID == template.persistentModelID
        }
        return inSession.map { $0.endedAt ?? $0.startedAt }.max() ?? .distantPast
    }

    // MARK: - Раскладка

    private func computeLayout(
        sizes: [PersistentIdentifier: CircleSizeClass],
        in size: CGSize
    ) -> [ClusterID: CGPoint] {
        var hero: ClusterLayout.Item?
        var others: [ClusterLayout.Item] = []

        for template in templates {
            let id = template.persistentModelID
            let sizeClass = sizes[id] ?? .m
            let item = ClusterLayout.Item(id: .template(id), diameter: sizeClass.diameter)
            if sizeClass == .hero {
                hero = item
            } else {
                others.append(item)
            }
        }
        others.append(ClusterLayout.Item(id: .add, diameter: 60))

        return ClusterLayout.positions(hero: hero, others: others, in: size)
    }

    private func layoutSignature(sizes: [PersistentIdentifier: CircleSizeClass]) -> String {
        templates
            .map { "\($0.persistentModelID.hashValue):\(sizes[$0.persistentModelID]?.diameter ?? 0)" }
            .joined(separator: "|")
    }

    // MARK: - Кружки

    @ViewBuilder
    private func circleView(_ template: ActivityTemplate, sizeClass: CircleSizeClass) -> some View {
        Group {
            if sizeClass == .hero, let entry = activeEntry {
                HeroCircleView(
                    template: template,
                    entry: entry,
                    progress: heroProgress(entry: entry)
                )
            } else {
                ActivityCircleView(
                    template: template,
                    sizeClass: sizeClass,
                    isGrown: sizeClass == .l
                )
            }
        }
        .contentShape(Circle())
        .onTapGesture { onTap(template) }
        .contextMenu {
            Button {
                onEdit(template)
            } label: {
                Label("Редактировать", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(template)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    /// Кольцо hero: лимит активности, если задан; иначе для работы — прогресс
    /// к перерыву, для остальных — к «типичным» 15 мин.
    private func heroProgress(entry: ActivityEntry) -> Double {
        let elapsed = entry.duration(asOf: now)
        let target: Double
        if let limit = entry.template?.plannedMinutes, limit > 0 {
            target = Double(limit * 60)
        } else if entry.category == .work {
            target = Double(breakIntervalMinutes * 60)
        } else {
            target = 15 * 60
        }
        return min(1, max(0.02, elapsed / target))
    }
}

// MARK: - Hero-кружок с кольцом прогресса

struct HeroCircleView: View {
    let template: ActivityTemplate
    let entry: ActivityEntry
    let progress: Double

    private var color: Color { template.color }
    private let diameter = CircleSizeClass.hero.diameter

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Theme.card)
                .padding(8)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: template.iconName)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(color)
                        Text(template.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 20)
                        Text(timerInterval: entry.startedAt...Date.distantFuture, countsDown: false)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                    }
                }
        }
        .padding(4)
        .frame(width: diameter, height: diameter)
        .shadow(color: color.opacity(0.4), radius: 16, y: 10)
    }
}

// MARK: - Обычный кружок

struct ActivityCircleView: View {
    let template: ActivityTemplate
    let sizeClass: CircleSizeClass
    let isGrown: Bool

    private var color: Color { template.color }
    private var diameter: CGFloat { sizeClass.diameter }
    private var isDistraction: Bool { template.category == .distraction }

    private var iconSize: CGFloat {
        switch sizeClass {
        case .l: 27
        case .m: 22
        default: 18
        }
    }

    private var labelFont: Font {
        switch sizeClass {
        case .l: .system(size: 12, weight: .semibold)
        case .m: .system(size: 11.5, weight: .medium)
        default: .system(size: 10, weight: .medium)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.mix(with: Theme.card, by: isGrown ? 0.72 : 0.78),
                            color.mix(with: Theme.card, by: isGrown ? 0.84 : 0.87),
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 0,
                        endRadius: diameter * 0.85
                    )
                )
                .overlay(Circle().strokeBorder(color.opacity(isGrown ? 0.32 : 0.25), lineWidth: 1))

            VStack(spacing: sizeClass == .l ? 5 : 3) {
                Image(systemName: template.iconName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(color)
                Text(template.name)
                    .font(labelFont)
                    .foregroundStyle(isGrown ? Theme.text : Theme.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            if isGrown {
                ZStack {
                    Circle().fill(color)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 20, height: 20)
                .offset(x: -diameter * 0.08, y: diameter * 0.07)
            }
        }
        .background {
            if isGrown {
                Circle()
                    .stroke(color.opacity(0.10), lineWidth: 4)
                    .padding(-2)
            }
        }
        .shadow(
            color: isGrown ? color.opacity(0.4) : .black.opacity(0.10),
            radius: isGrown ? 14 : 10,
            y: isGrown ? 9 : 6
        )
        .opacity(isDistraction ? 0.78 : 1)
    }
}

// MARK: - «+ Добавить»

struct AddCircleView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.card2)
                Circle()
                    .strokeBorder(
                        Theme.text3,
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                    Text("Добавить")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Theme.text3)
            }
            .frame(width: 60, height: 60)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
