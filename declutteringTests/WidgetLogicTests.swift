import Foundation
import Photos
import Testing
@testable import decluttering

struct WidgetLogicTests {

    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0,
                      in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    // MARK: interleave

    @Test func interleaveTakesOnePerGroupInTurn() {
        #expect(WidgetLogic.interleave([[1, 2, 3], [10, 20, 30], [100, 200, 300]], limit: 9)
                == [1, 10, 100, 2, 20, 200, 3, 30, 300])
    }

    @Test func interleaveHandlesUnevenGroups() {
        #expect(WidgetLogic.interleave([[1, 2, 3, 4], [10], [100, 200]], limit: 10)
                == [1, 10, 100, 2, 200, 3, 4])
    }

    @Test func interleaveSkipsEmptyGroups() {
        #expect(WidgetLogic.interleave([[], [1, 2], [], [10]], limit: 10) == [1, 10, 2])
    }

    @Test func interleaveWithNoGroupsOrOnlyEmptyGroupsIsEmpty() {
        #expect(WidgetLogic.interleave([[Int]](), limit: 5).isEmpty)
        #expect(WidgetLogic.interleave([[Int](), [Int]()], limit: 5).isEmpty)
    }

    @Test func interleaveLimitSmallerThanGroupCountStopsMidRound() {
        #expect(WidgetLogic.interleave([[1, 2], [10, 20], [100, 200]], limit: 2) == [1, 10])
        #expect(WidgetLogic.interleave([[1, 2], [10, 20], [100, 200]], limit: 4) == [1, 10, 100, 2])
    }

    @Test func interleaveLimitOfZeroOrNegativeIsEmpty() {
        #expect(WidgetLogic.interleave([[1, 2]], limit: 0).isEmpty)
        #expect(WidgetLogic.interleave([[1, 2]], limit: -3).isEmpty)
    }

    @Test func interleaveLimitLargerThanAvailableReturnsEverything() {
        #expect(WidgetLogic.interleave([[1], [2, 3]], limit: 100) == [1, 2, 3])
    }

    @Test func interleaveKeepsOrderWithinEachGroup() {
        let result = WidgetLogic.interleave([["a1", "a2", "a3"], ["b1", "b2", "b3"]], limit: 8)
        #expect(result.filter { $0.hasPrefix("a") } == ["a1", "a2", "a3"])
        #expect(result.filter { $0.hasPrefix("b") } == ["b1", "b2", "b3"])
    }

    // MARK: yearsAgoText

    @Test func yearsAgoTextWordsEachCase() {
        let cal = calendar()
        let now = date(2026, 6, 15, 12, in: cal)
        #expect(WidgetLogic.yearsAgoText(for: date(2026, 1, 1, in: cal), now: now, calendar: cal) == "Today")
        #expect(WidgetLogic.yearsAgoText(for: date(2025, 6, 15, in: cal), now: now, calendar: cal) == "1 year ago")
        #expect(WidgetLogic.yearsAgoText(for: date(2024, 6, 15, in: cal), now: now, calendar: cal) == "2 years ago")
        #expect(WidgetLogic.yearsAgoText(for: date(2016, 6, 15, in: cal), now: now, calendar: cal) == "10 years ago")
    }

    @Test func yearsAgoTextCountsCalendarYearsAcrossNewYear() {
        let cal = calendar()
        // One second apart but in different calendar years.
        let now = date(2026, 1, 1, 0, 0, 0, in: cal)
        let lastSecond = date(2025, 12, 31, 23, 59, 59, in: cal)
        #expect(WidgetLogic.yearsAgoText(for: lastSecond, now: now, calendar: cal) == "1 year ago")
        // Same year at both ends of the year is still today.
        let endOfYear = date(2026, 12, 31, 23, 59, 59, in: cal)
        #expect(WidgetLogic.yearsAgoText(for: now, now: endOfYear, calendar: cal) == "Today")
    }

    @Test func yearsAgoTextForLeapDay() {
        let cal = calendar()
        let leapDay = date(2024, 2, 29, in: cal)
        #expect(WidgetLogic.yearsAgoText(for: leapDay, now: date(2028, 2, 29, in: cal), calendar: cal) == "4 years ago")
        #expect(WidgetLogic.yearsAgoText(for: leapDay, now: date(2025, 3, 1, in: cal), calendar: cal) == "1 year ago")
        #expect(WidgetLogic.yearsAgoText(for: leapDay, now: date(2024, 12, 31, in: cal), calendar: cal) == "Today")
    }

    @Test func yearsAgoTextUsesTheGivenCalendarTimeZone() {
        // 2025-12-31 23:30 UTC is already 2026 in Auckland.
        let instant = date(2025, 12, 31, 23, 30, in: calendar("UTC"))
        let auckland = calendar("Pacific/Auckland")
        let utc = calendar("UTC")
        let photo = date(2025, 6, 1, in: utc)
        #expect(WidgetLogic.yearsAgoText(for: photo, now: instant, calendar: utc) == "Today")
        #expect(WidgetLogic.yearsAgoText(for: photo, now: instant, calendar: auckland) == "1 year ago")
    }

    @Test func yearsAgoTextKeepsExistingBehaviourForFutureDates() {
        let cal = calendar()
        #expect(WidgetLogic.yearsAgoText(for: date(2027, 1, 1, in: cal), now: date(2026, 1, 1, in: cal), calendar: cal)
                == "-1 years ago")
    }

    // MARK: streakLine

    @Test func streakLineText() {
        #expect(WidgetLogic.streakLine(1) == "1-day streak")
        #expect(WidgetLogic.streakLine(3) == "3-day streak")
        #expect(WidgetLogic.streakLine(365) == "365-day streak")
        #expect(WidgetLogic.streakLine(0) == "Sort a photo to start a streak")
        #expect(WidgetLogic.streakLine(-2) == "Sort a photo to start a streak")
    }

    // MARK: plan

    private struct Item: Equatable {
        let id: String
    }

    private func groups(_ ids: [[String]]) -> [[Item]] {
        ids.map { $0.map(Item.init) }
    }

    private func plan(access: Bool = true, kept: Set<String> = [], limit: Int = 8, _ ids: [[String]])
        -> WidgetLogic.Plan<Item> {
        WidgetLogic.plan(hasAccess: access, keptIDs: kept, limit: limit, id: \.id, loadGroups: { groups(ids) })
    }

    @Test func planPicksPhotosInterleavedByYear() {
        guard case .photos(let items) = plan([["a1", "a2"], ["b1"]]) else { Issue.record("expected photos"); return }
        #expect(items.map(\.id) == ["a1", "b1", "a2"])
    }

    @Test func planDropsKeptPhotosBeforeInterleaving() {
        guard case .photos(let items) = plan(kept: ["a1", "b2"], [["a1", "a2"], ["b1", "b2"]]) else {
            Issue.record("expected photos"); return
        }
        #expect(items.map(\.id) == ["a2", "b1"])
    }

    @Test func planRespectsLimit() {
        guard case .photos(let items) = plan(limit: 2, [["a1", "a2"], ["b1", "b2"], ["c1"]]) else {
            Issue.record("expected photos"); return
        }
        #expect(items.map(\.id) == ["a1", "b1"])
    }

    @Test func planIsCaughtUpWithPhotosWhenEverythingIsKept() {
        guard case .caughtUp(let hadPhotos) = plan(kept: ["a1", "b1"], [["a1"], ["b1"]]) else {
            Issue.record("expected caughtUp"); return
        }
        #expect(hadPhotos)
    }

    @Test func planIsCaughtUpWithoutPhotosWhenNoYearHasAny() {
        for ids in [[[String]](), [[], []]] {
            guard case .caughtUp(let hadPhotos) = plan(ids) else { Issue.record("expected caughtUp"); return }
            #expect(!hadPhotos)
        }
    }

    @Test func planIsCaughtUpWhenLimitIsZero() {
        guard case .caughtUp(let hadPhotos) = plan(limit: 0, [["a1"]]) else { Issue.record("expected caughtUp"); return }
        #expect(hadPhotos)
    }

    @Test func planWithoutAccessIsNoAccessAndNeverLoadsPhotos() {
        var loaded = false
        let result = WidgetLogic.plan(hasAccess: false, keptIDs: [], limit: 8, id: \Item.id) { () -> [[Item]] in
            loaded = true
            return [[Item(id: "a")]]
        }
        guard case .noAccess = result else { Issue.record("expected noAccess"); return }
        #expect(!loaded)
    }

    @Test func accessIsGrantedOnlyForAuthorizedAndLimited() {
        #expect(WidgetLogic.hasAccess(.authorized))
        #expect(WidgetLogic.hasAccess(.limited))
        #expect(!WidgetLogic.hasAccess(.denied))
        #expect(!WidgetLogic.hasAccess(.restricted))
        #expect(!WidgetLogic.hasAccess(.notDetermined))
    }

    // MARK: refresh date

    private let halfHour: TimeInterval = 30 * 60

    @Test func refreshIsLastEntryPlusIntervalWhenBeforeMidnight() {
        let cal = calendar()
        let now = date(2026, 6, 15, 10, in: cal)
        let last = now.addingTimeInterval(halfHour * 7)
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: last, now: now, refreshInterval: halfHour, calendar: cal)
        #expect(next == last.addingTimeInterval(halfHour))
    }

    @Test func refreshIsCappedAtMidnight() {
        let cal = calendar()
        let now = date(2026, 6, 15, 23, 40, in: cal)
        let last = now.addingTimeInterval(halfHour * 7)
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: last, now: now, refreshInterval: halfHour, calendar: cal)
        #expect(next == date(2026, 6, 16, in: cal))
    }

    @Test func refreshWithoutEntriesUsesNow() {
        let cal = calendar()
        let now = date(2026, 6, 15, 10, in: cal)
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: nil, now: now, refreshInterval: halfHour, calendar: cal)
        #expect(next == now.addingTimeInterval(halfHour))
    }

    @Test func refreshAtExactlyMidnightPicksTheFollowingMidnight() {
        let cal = calendar()
        let now = date(2026, 6, 15, in: cal)
        #expect(WidgetLogic.nextMidnight(after: now, calendar: cal) == date(2026, 6, 16, in: cal))
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: nil, now: now, refreshInterval: 48 * 3600, calendar: cal)
        #expect(next == date(2026, 6, 16, in: cal))
    }

    @Test func midnightRollsOverMonthAndYear() {
        let cal = calendar()
        #expect(WidgetLogic.nextMidnight(after: date(2026, 12, 31, 23, 59, 59, in: cal), calendar: cal)
                == date(2027, 1, 1, in: cal))
        #expect(WidgetLogic.nextMidnight(after: date(2028, 2, 28, 12, in: cal), calendar: cal)
                == date(2028, 2, 29, in: cal))
        #expect(WidgetLogic.nextMidnight(after: date(2028, 2, 29, 12, in: cal), calendar: cal)
                == date(2028, 3, 1, in: cal))
    }

    @Test func midnightOnSpringForwardDayIsTwentyThreeHoursAway() {
        let cal = calendar("America/New_York")
        let now = date(2026, 3, 8, 0, 30, in: cal)
        let midnight = WidgetLogic.nextMidnight(after: now, calendar: cal)
        #expect(midnight == date(2026, 3, 9, in: cal))
        #expect(midnight.timeIntervalSince(now) == 22.5 * 3600)
    }

    @Test func midnightOnFallBackDayIsTwentyFiveHoursAway() {
        let cal = calendar("America/New_York")
        let now = date(2026, 11, 1, 0, 30, in: cal)
        let midnight = WidgetLogic.nextMidnight(after: now, calendar: cal)
        #expect(midnight == date(2026, 11, 2, in: cal))
        #expect(midnight.timeIntervalSince(now) == 24.5 * 3600)
    }

    @Test func midnightIsAlwaysInTheFutureAcrossDSTChanges() {
        let cal = calendar("America/New_York")
        var now = date(2026, 3, 6, 18, in: cal)
        for _ in 0..<(5 * 24) {
            let midnight = WidgetLogic.nextMidnight(after: now, calendar: cal)
            #expect(midnight > now)
            #expect(cal.component(.hour, from: midnight) == 0)
            #expect(midnight.timeIntervalSince(now) <= 25 * 3600)
            now = now.addingTimeInterval(3600)
        }
    }

    @Test func midnightThatDoesNotExistFallsToTheNextValidTime() {
        // Sao Paulo skipped 00:00 on 2018-11-04 when DST started.
        let cal = calendar("America/Sao_Paulo")
        let now = date(2018, 11, 3, 12, in: cal)
        let midnight = WidgetLogic.nextMidnight(after: now, calendar: cal)
        #expect(midnight > now)
        #expect(cal.component(.day, from: midnight) == 4)
        #expect(midnight.timeIntervalSince(now) < 24 * 3600)
    }

    @Test func refreshAcrossSpringForwardStillCapsAtMidnight() {
        let cal = calendar("America/New_York")
        let now = date(2026, 3, 7, 23, 50, in: cal)
        let last = now.addingTimeInterval(halfHour * 7)
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: last, now: now, refreshInterval: halfHour, calendar: cal)
        #expect(next == date(2026, 3, 8, in: cal))
    }
}
