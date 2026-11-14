import Foundation

nonisolated enum BreakLevel: Int {
    case none = 0
    case gentle = 1
    case rest = 2
}

/// Decides when to suggest a break. Sorting a few photos is soothing; sorting hundreds is a chore,
/// so Binny steps in at two points each day, once each.
nonisolated struct BreakPolicy {

    // Photos sorted in a day before Binny suggests a short break, and then a proper rest.
    static let gentleAt = 40
    static let restAt = 100

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let dayKey = "breakNudge.day"
    private let levelKey = "breakNudge.level"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    static func level(forCount count: Int) -> BreakLevel {
        count >= restAt ? .rest : (count >= gentleAt ? .gentle : .none)
    }

    /// The reminder to show now, or nil. Each level is returned at most once per day, so people can
    /// carry on after a nudge without being asked again. Jumping straight past both gives just the stronger one.
    func nudge(forCount count: Int, now: Date = .now) -> BreakLevel? {
        let level = Self.level(forCount: count)
        guard level != .none else { return nil }

        let today = calendar.startOfDay(for: now).timeIntervalSince1970
        let alreadyShown = defaults.double(forKey: dayKey) == today ? BreakLevel(rawValue: defaults.integer(forKey: levelKey)) ?? .none : .none
        guard level.rawValue > alreadyShown.rawValue else { return nil }

        defaults.set(today, forKey: dayKey)
        defaults.set(level.rawValue, forKey: levelKey)
        return level
    }
}
