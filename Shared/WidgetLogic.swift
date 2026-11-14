import Foundation
import Photos

/// Pure widget logic, shared with the app target so it can be unit tested.
nonisolated enum WidgetLogic {

    /// What the widget should show, before any images are loaded.
    enum Plan<Item> {
        case noAccess
        /// Nothing left to sort. `hadPhotos` is false when no group had a photo at all.
        case caughtUp(hadPhotos: Bool)
        case photos([Item])
    }

    static func hasAccess(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    /// Chooses the widget content. `loadGroups` only runs when access is granted.
    static func plan<Item>(hasAccess: Bool,
                           keptIDs: Set<String>,
                           limit: Int,
                           id: (Item) -> String,
                           loadGroups: () -> [[Item]]) -> Plan<Item> {
        guard hasAccess else { return .noAccess }
        let groups = loadGroups()
        let remaining = groups.map { $0.filter { !keptIDs.contains(id($0)) } }
        let items = interleave(remaining, limit: limit)
        guard !items.isEmpty else {
            return .caughtUp(hadPhotos: groups.contains { !$0.isEmpty })
        }
        return .photos(items)
    }

    /// Takes one element per group in turn so every group (year) is represented.
    static func interleave<Element>(_ groups: [[Element]], limit: Int) -> [Element] {
        var result: [Element] = []
        var index = 0
        while result.count < limit {
            var added = false
            for group in groups where index < group.count {
                result.append(group[index])
                added = true
                if result.count == limit { break }
            }
            if !added { break }
            index += 1
        }
        return result
    }

    static func yearsAgoText(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let years = calendar.component(.year, from: now) - calendar.component(.year, from: date)
        switch years {
        case 0: return "Today"
        case 1: return "1 year ago"
        default: return "\(years) years ago"
        }
    }

    static func streakLine(_ streak: Int) -> String {
        streak > 0 ? "\(streak)-day streak" : "Sort a photo to start a streak"
    }

    static func nextMidnight(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(3600)
    }

    /// The earlier of "last entry + refresh interval" and the next midnight.
    static func nextRefreshDate(lastEntryDate: Date?, now: Date = .now, refreshInterval: TimeInterval,
                                calendar: Calendar = .current) -> Date {
        min((lastEntryDate ?? now).addingTimeInterval(refreshInterval),
            nextMidnight(after: now, calendar: calendar))
    }
}
