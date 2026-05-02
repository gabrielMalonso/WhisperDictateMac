import Foundation

extension Date {
    /// Returns a concise relative time string (e.g. "3 min", "2 h", "5 dias", "1 sem").
    /// Does not include seconds to avoid constant UI updates.
    func relativeShort(to now: Date = .now) -> String {
        let elapsed = now.timeIntervalSince(self)
        guard elapsed >= 0 else { return AppText.justNow() }

        let minutes = Int(elapsed / 60)
        let hours = Int(elapsed / 3600)
        let days = Int(elapsed / 86400)
        let weeks = Int(elapsed / 604_800)

        if minutes < 1 {
            return AppText.justNow()
        } else if minutes < 60 {
            return AppText.shortMinuteCount(minutes)
        } else if hours < 24 {
            return AppText.shortHourCount(hours)
        } else if days < 7 {
            return AppText.dayCount(days)
        } else {
            return AppText.shortWeekCount(weeks)
        }
    }
}
