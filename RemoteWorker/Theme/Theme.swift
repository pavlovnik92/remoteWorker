import SwiftUI
import UIKit

// Дизайн-токены из handoff (README.md пакета design_handoff_udalenshik).

nonisolated extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

nonisolated extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

enum Theme {
    static let bg = Color(light: 0xF0EBE1, dark: 0x15130F)
    static let card = Color(light: 0xFFFFFF, dark: 0x211E18)
    static let card2 = Color(light: 0xF8F4EC, dark: 0x2B2820)
    static let text = Color(light: 0x1C1C1E, dark: 0xF5F5F7)
    static let text2 = Color(light: 0x6C6C70, dark: 0x9E9EA3)
    static let text3 = Color(light: 0xAEAEB2, dark: 0x636367)
    static let accent = Color(light: 0x1E8A5B, dark: 0x34B57E)
    static let separator = Color(light: 0x3C301C, dark: 0xFFFFFF, lightAlpha: 0.09, darkAlpha: 0.09)

    // Дополнительные цвета свотчей из S2a
    static let violet = Color(light: 0x7A5AF0, dark: 0x8E71F5)
    static let teal = Color(light: 0x2BB3C0, dark: 0x3FC6D3)
    static let indigo = Color(light: 0x5B5BD6, dark: 0x7373E8)
}

extension ShapeStyle where Self == Color {
    static var themeBG: Color { Theme.bg }
}

// MARK: - Переиспользуемые стили

struct CardBackground: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
            )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

/// Акцентная кнопка с радиальным градиентом («Начать день», «Завершить»).
struct AccentButtonStyle: ButtonStyle {
    var base: Color = Theme.accent
    var height: CGFloat = 56
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [base.mix(with: .white, by: 0.28), base],
                            center: UnitPoint(x: 0.36, y: 0.22),
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .shadow(color: base.opacity(0.45), radius: 13, y: 8)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Нейтральная белая кнопка («Пауза»).
struct NeutralButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .cardStyle(cornerRadius: cornerRadius)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
