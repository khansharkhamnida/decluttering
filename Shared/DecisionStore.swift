import Foundation
import SwiftData
import WidgetKit

enum DecisionKind: String {
    case kept
    case binned
}

/// One thing you decided about a photo. Powers the "kept" list, the stats and the streak.
@Model
final class Decision {
    var assetID: String
    var kindRaw: String
    var date: Date

    init(assetID: String, kind: DecisionKind, date: Date = .now) {
        self.assetID = assetID
        self.kindRaw = kind.rawValue
        self.date = date
    }

    init(assetID: String, kindRaw: String, date: Date) {
        self.assetID = assetID
        self.kindRaw = kindRaw
        self.date = date
    }
}

struct BoothStats {
    let binned: Int
    let kept: Int
    let streak: Int
}

@MainActor
protocol DecisionRecording: AnyObject {
    func recordKept(ids: [String])
    func recordBinned(ids: [String])
    func removeKept(ids: [String])
    func keptIDs() -> Set<String>
    func stats() -> BoothStats
    func todayCount() -> Int
    func resetKept()
}

@MainActor
final class DecisionStore: DecisionRecording {

    static let shared = DecisionStore()

    static let appGroupID = "group.com.khansharkhamnida.decluttering"
    private static let migrationKey = "decisionsMigratedToAppGroup"

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// The store lives in the App Group so the widget can see which photos are kept.
    /// Falls back to the app's own storage, then to memory, so the booth always works.
    private init() {
        let schema = Schema([Decision.self])

        // SwiftData's own group-container option crashes when the entitlement is missing,
        // so the shared folder is resolved here, where a missing group is just nil.
        if let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID),
           let shared = try? ModelContainer(for: schema, configurations: ModelConfiguration(
               "BoothDecisions", schema: schema, url: folder.appendingPathComponent("BoothDecisions.store"))) {
            container = shared
            Self.migrateLegacyDecisions(into: shared)
        } else if let persistent = try? ModelContainer(for: Decision.self) {
            container = persistent
        } else {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: Decision.self, configurations: memory)
        }
    }

    /// Earlier versions kept decisions in the app's private storage. Copies them over once.
    private static func migrateLegacyDecisions(into shared: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: migrationKey)
        let isEmpty = ((try? shared.mainContext.fetchCount(FetchDescriptor<Decision>())) ?? 0) == 0
        guard isEmpty, let legacy = try? ModelContainer(for: Decision.self) else { return }
        for old in (try? legacy.mainContext.fetch(FetchDescriptor<Decision>())) ?? [] {
            shared.mainContext.insert(Decision(assetID: old.assetID, kindRaw: old.kindRaw, date: old.date))
        }
        try? shared.mainContext.save()
    }

    /// The widget's timeline code is not guaranteed to run on the main thread, so it reads through this.
    nonisolated static func keptIDsSnapshot() -> Set<String> {
        if Thread.isMainThread { return MainActor.assumeIsolated { shared.keptIDs() } }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { shared.keptIDs() } }
    }

    /// The current day streak, read the same way for the widget.
    nonisolated static func streakSnapshot() -> Int {
        // Only the decision days are read on the main thread; the photo lookups run on the caller's thread.
        let days: Set<Date>
        if Thread.isMainThread { days = MainActor.assumeIsolated { shared.decisionDays() } }
        else { days = DispatchQueue.main.sync { MainActor.assumeIsolated { shared.decisionDays() } } }
        return streak(decisionDays: days, hadPhotosOn: PhotoLibraryService().hadPhotosPredicate())
    }

    func recordKept(ids: [String]) {
        let existing = keptIDs()
        for id in ids where !existing.contains(id) {
            context.insert(Decision(assetID: id, kind: .kept))
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func recordBinned(ids: [String]) {
        ids.forEach { context.insert(Decision(assetID: $0, kind: .binned)) }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeKept(ids: [String]) {
        let kept = DecisionKind.kept.rawValue
        let descriptor = FetchDescriptor<Decision>(predicate: #Predicate { $0.kindRaw == kept })
        let targets = Set(ids)
        for decision in (try? context.fetch(descriptor)) ?? [] where targets.contains(decision.assetID) {
            context.delete(decision)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func keptIDs() -> Set<String> {
        let kept = DecisionKind.kept.rawValue
        let descriptor = FetchDescriptor<Decision>(predicate: #Predicate { $0.kindRaw == kept })
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.assetID))
    }

    /// Photos kept or binned since midnight. Drives the break reminders.
    func todayCount() -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        return (try? context.fetchCount(FetchDescriptor<Decision>(predicate: #Predicate { $0.date >= start }))) ?? 0
    }

    func stats() -> BoothStats {
        let kept = DecisionKind.kept.rawValue
        let binned = DecisionKind.binned.rawValue
        let keptCount = (try? context.fetchCount(FetchDescriptor<Decision>(predicate: #Predicate { $0.kindRaw == kept }))) ?? 0
        let binnedCount = (try? context.fetchCount(FetchDescriptor<Decision>(predicate: #Predicate { $0.kindRaw == binned }))) ?? 0
        return BoothStats(binned: binnedCount, kept: keptCount, streak: currentStreak())
    }

    func resetKept() {
        let kept = DecisionKind.kept.rawValue
        try? context.delete(model: Decision.self, where: #Predicate { $0.kindRaw == kept })
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The start of every day that has at least one decision.
    func decisionDays(calendar: Calendar = .current) -> Set<Date> {
        let all = (try? context.fetch(FetchDescriptor<Decision>())) ?? []
        return Set(all.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive days with at least one decision, skipping days with nothing to sort.
    /// `hadPhotosOn` defaults to the photo library; without photo access every day counts.
    func currentStreak(calendar: Calendar = .current, hadPhotosOn: (@Sendable (Date) -> Bool)? = nil) -> Int {
        let predicate = hadPhotosOn ?? PhotoLibraryService().hadPhotosPredicate(calendar: calendar)
        return Self.streak(decisionDays: decisionDays(calendar: calendar), hadPhotosOn: predicate, calendar: calendar)
    }

    /// Walks back from today counting days with a decision.
    /// - A day with no decision and no photos to sort is skipped: it neither adds to nor breaks the streak.
    /// - A day with photos but no decision breaks it. Today is the exception: it can still be sorted.
    /// - Without `hadPhotosOn` (no photo access) no day is skipped.
    /// The photo check only runs for days missing a decision, at most `maxSkippedDays` times, and never
    /// past the oldest decision.
    nonisolated static func streak(
        decisionDays: Set<Date>,
        hadPhotosOn: (@Sendable (Date) -> Bool)?,
        now: Date = .now,
        calendar: Calendar = .current,
        maxSkippedDays: Int = 400
    ) -> Int {
        let days = Set(decisionDays.map { calendar.startOfDay(for: $0) })
        guard let earliest = days.min() else { return 0 }

        let today = calendar.startOfDay(for: now)
        var cursor = today
        var streak = 0
        var skipped = 0
        while cursor >= earliest {
            if days.contains(cursor) {
                streak += 1
            } else if cursor != today {
                guard let hadPhotosOn, skipped < maxSkippedDays, !hadPhotosOn(cursor) else { break }
                skipped += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
