import Foundation

public enum RelativeTime {
    /// "Just now", "5m ago", "2h ago", "Yesterday", a weekday within a week, then a short date.
    public static func text(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days == 0 {
            return seconds < 3600 ? "\(Int(seconds / 60))m ago" : "\(Int(seconds / 3600))h ago"
        }
        if days == 1 { return "Yesterday" }
        let format = DateFormatter()
        format.calendar = calendar
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = days < 7 ? "EEE" : "MMM d"
        return format.string(from: date)
    }
}
