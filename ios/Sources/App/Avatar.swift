import SwiftUI

extension String {
    var initials: String {
        let parts = self.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }
}

struct AvatarView: View {
    let title: String
    var size: CGFloat = 44

    var body: some View {
        let color = Self.color(for: title)
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(title.initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    static let palette: [Color] = [
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.98, green: 0.47, blue: 0.40),
        Color(red: 0.40, green: 0.78, blue: 0.55),
        Color(red: 0.85, green: 0.55, blue: 0.93),
        Color(red: 0.99, green: 0.78, blue: 0.30),
        Color(red: 0.55, green: 0.70, blue: 0.95),
        Color(red: 0.94, green: 0.55, blue: 0.62),
        Color(red: 0.45, green: 0.80, blue: 0.80)
    ]

    static func color(for key: String) -> Color {
        guard !key.isEmpty else { return Color.gray }
        let h = key.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return palette[abs(h) % palette.count]
    }
}

func chatTime(_ s: String?) -> String {
    guard let s, let d = isoDate(s) else { return "" }
    let cal = Calendar.current
    let fmt = DateFormatter()
    if cal.isDateInToday(d) { fmt.dateFormat = "HH:mm" }
    else if cal.isDateInYesterday(d) { return "Вчера" }
    else if cal.component(.year, from: d) == cal.component(.year, from: Date()) { fmt.dateFormat = "dd MMM" }
    else { fmt.dateFormat = "dd.MM.yy" }
    return fmt.string(from: d)
}

func msgTime(_ s: String?) -> String {
    guard let s, let d = isoDate(s) else { return "" }
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    return fmt.string(from: d)
}

func isoDate(_ s: String) -> Date? {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    if let d = fmt.date(from: s) { return d }
    fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    fmt.timeZone = TimeZone(secondsFromGMT: 0)
    return fmt.date(from: s)
}
