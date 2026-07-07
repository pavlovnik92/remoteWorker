import Foundation

enum Format {
    static let locale = Locale(identifier: "ru_RU")

    /// «6ч 42м» — для сводок.
    static func hoursMinutes(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return "\(m)м" }
        return "\(h)ч \(m)м"
    }

    /// «47:12» или «1:04:09» — для таймеров в статичном контексте.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    /// «Четверг, 26 июня»
    static func dayTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "EEEE, d MMMM"
        let s = f.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// «18:24»
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// «Вчера» / «Сегодня» / «26 июня»
    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Сегодня" }
        if cal.isDateInYesterday(date) { return "Вчера" }
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    /// «Доброе утро» / «Добрый день» / «Добрый вечер»
    static func greeting(for date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        default: return "Добрый вечер"
        }
    }

    /// «1 разминка», «3 разминки», «5 разминок».
    static func plural(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        let word: String
        if (11...14).contains(mod100) {
            word = many
        } else if mod10 == 1 {
            word = one
        } else if (2...4).contains(mod10) {
            word = few
        } else {
            word = many
        }
        return "\(count) \(word)"
    }
}
