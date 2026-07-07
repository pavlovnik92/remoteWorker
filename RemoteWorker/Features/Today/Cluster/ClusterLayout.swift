import CoreGraphics
import Foundation
import SwiftData

enum ClusterID: Hashable {
    case template(PersistentIdentifier)
    case add
}

/// Классы размера кружков из легенды S2.
enum CircleSizeClass {
    case hero, l, m, s, xs

    var diameter: CGFloat {
        switch self {
        case .hero: 150
        case .l: 108
        case .m: 82
        case .s: 64
        case .xs: 52
        }
    }
}

/// Детерминированная органическая раскладка: hero в верхней трети,
/// остальные — по золотой спирали вокруг него, без пересечений (зазор ≥ gap).
enum ClusterLayout {
    struct Item {
        let id: ClusterID
        let diameter: CGFloat
    }

    static func positions(
        hero: Item?,
        others: [Item],
        in size: CGSize,
        gap: CGFloat = 10
    ) -> [ClusterID: CGPoint] {
        var result: [ClusterID: CGPoint] = [:]
        guard size.width > 80, size.height > 80 else { return result }

        var placed: [(center: CGPoint, radius: CGFloat)] = []

        func inside(_ p: CGPoint, radius r: CGFloat) -> Bool {
            p.x - r >= 0 && p.x + r <= size.width && p.y - r >= 0 && p.y + r <= size.height
        }

        func collides(_ p: CGPoint, radius r: CGFloat) -> Bool {
            placed.contains { other in
                let dx = p.x - other.center.x
                let dy = p.y - other.center.y
                let minDist = r + other.radius + gap
                return dx * dx + dy * dy < minDist * minDist
            }
        }

        let anchor: CGPoint
        if let hero {
            let r = hero.diameter / 2
            anchor = CGPoint(x: size.width / 2, y: min(r + 2, size.height - r))
            result[hero.id] = anchor
            placed.append((anchor, r))
        } else {
            anchor = CGPoint(x: size.width / 2, y: size.height * 0.30)
        }

        let goldenAngle: CGFloat = 2.39996323

        for (index, item) in others.enumerated() {
            let r = item.diameter / 2
            let baseAngle = goldenAngle * CGFloat(index) + 0.9
            var distance = (hero?.diameter ?? 96) / 2 + r + gap
            var found: CGPoint?

            searchLoop: while distance < size.width + size.height {
                for step in 0..<16 {
                    // Веер вокруг базового угла: 0, +0.42, -0.42, +0.84, ...
                    let wiggle = CGFloat((step + 1) / 2) * 0.42 * (step.isMultiple(of: 2) ? 1 : -1)
                    let angle = baseAngle + wiggle
                    let candidate = CGPoint(
                        x: anchor.x + cos(angle) * distance,
                        y: anchor.y + sin(angle) * distance * 1.16
                    )
                    if inside(candidate, radius: r), !collides(candidate, radius: r) {
                        found = candidate
                        break searchLoop
                    }
                }
                distance += 7
            }

            let point = found ?? CGPoint(
                x: size.width / 2,
                y: max(r, size.height - r - 2)
            )
            result[item.id] = point
            placed.append((point, r))
        }

        return result
    }
}
