import Foundation
import SwiftUI

/// Ключи настроек. Вьюхи используют @AppStorage с этими же ключами,
/// сервисы читают статические аксессоры.
enum AppSettings {
    static let breakIntervalKey = "settings.breakIntervalMinutes"
    static let adaptiveBreaksKey = "settings.adaptiveBreaks"
    static let quietStartKey = "settings.quietStartMinutes"
    static let quietEndKey = "settings.quietEndMinutes"
    static let themeKey = "settings.theme"
    static let userNameKey = "settings.userName"
    static let notificationsEnabledKey = "settings.notificationsEnabled"

    static var breakIntervalMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: breakIntervalKey)
        return v == 0 ? 50 : v
    }

    static var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: notificationsEnabledKey) as? Bool ?? true
    }

    /// Минуты от полуночи. По умолчанию 22:00–08:00.
    static var quietStartMinutes: Int {
        UserDefaults.standard.object(forKey: quietStartKey) as? Int ?? 22 * 60
    }

    static var quietEndMinutes: Int {
        UserDefaults.standard.object(forKey: quietEndKey) as? Int ?? 8 * 60
    }

    static func isQuietTime(_ date: Date) -> Bool {
        let cal = Calendar.current
        let minutes = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        let start = quietStartMinutes
        let end = quietEndMinutes
        if start == end { return false }
        if start < end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end // интервал через полночь
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Система"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
