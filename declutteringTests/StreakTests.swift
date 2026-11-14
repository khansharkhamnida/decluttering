import Foundation
import Testing
@testable import decluttering

struct StreakTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 15))!
    }

    private func streak(
        decisions: [Date], now: Date, emptyDays: Set<Date>? = nil, hasAccess: Bool = true
    ) -> Int {
        let empty = Set((emptyDays ?? []).map { calendar.startOfDay(for: $0) })
        let cal = calendar
        let hadPhotos: @Sendable (Date) -> Bool = { !empty.contains(cal.startOfDay(for: $0)) }
        let predicate: (@Sendable (Date) -> Bool)? = hasAccess ? hadPhotos : nil
        return DecisionStore.streak(
            decisionDays: Set(decisions.map { calendar.startOfDay(for: $0) }),
            hadPhotosOn: predicate, now: now, calendar: calendar)
    }

    @Test func noDecisionsMeansNoStreak() {
        #expect(streak(decisions: [], now: day(2026, 3, 10)) == 0)
    }

    @Test func consecutiveDaysCount() {
        let decisions = [day(2026, 3, 10), day(2026, 3, 9), day(2026, 3, 8)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10)) == 3)
    }

    @Test func todayNotSortedYetKeepsYesterdaysStreak() {
        let decisions = [day(2026, 3, 9), day(2026, 3, 8)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10)) == 2)
    }

    @Test func todayEmptyDoesNotBreakYesterdaysStreak() {
        let decisions = [day(2026, 3, 9), day(2026, 3, 8)]
        let result = streak(decisions: decisions, now: day(2026, 3, 10), emptyDays: [day(2026, 3, 10)])
        #expect(result == 2)
    }

    @Test func emptyDayInTheMiddleIsBridged() {
        let decisions = [day(2026, 3, 10), day(2026, 3, 8), day(2026, 3, 7)]
        let result = streak(decisions: decisions, now: day(2026, 3, 10), emptyDays: [day(2026, 3, 9)])
        #expect(result == 3)
    }

    @Test func nonEmptyMissedDayBreaksTheStreak() {
        let decisions = [day(2026, 3, 10), day(2026, 3, 8), day(2026, 3, 7)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10)) == 1)
    }

    @Test func nonEmptyMissedDayYesterdayBreaksEvenWithOlderDecisions() {
        let decisions = [day(2026, 3, 8), day(2026, 3, 7)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10)) == 0)
    }

    @Test func skippedDaysDoNotAddToTheCount() {
        let decisions = [day(2026, 3, 10), day(2026, 3, 5)]
        let empty: Set<Date> = [day(2026, 3, 9), day(2026, 3, 8), day(2026, 3, 7), day(2026, 3, 6)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10), emptyDays: empty) == 2)
    }

    @Test func emptyDaysBeforeTheFirstDecisionAreNotCounted() {
        let empty: Set<Date> = [day(2026, 3, 9), day(2026, 3, 8)]
        #expect(streak(decisions: [day(2026, 3, 10)], now: day(2026, 3, 10), emptyDays: empty) == 1)
    }

    @Test func withoutPhotoAccessEveryMissedDayBreaks() {
        let decisions = [day(2026, 3, 10), day(2026, 3, 8)]
        let result = streak(decisions: decisions, now: day(2026, 3, 10), emptyDays: [day(2026, 3, 9)], hasAccess: false)
        #expect(result == 1)
    }

    @Test func withoutPhotoAccessConsecutiveDaysStillCount() {
        let decisions = [day(2026, 3, 9), day(2026, 3, 8)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 10), hasAccess: false) == 2)
    }

    @Test func monthBoundaryIsConsecutive() {
        let decisions = [day(2026, 3, 1), day(2026, 2, 28), day(2026, 2, 27)]
        #expect(streak(decisions: decisions, now: day(2026, 3, 1)) == 3)
    }

    @Test func yearBoundaryIsConsecutive() {
        let decisions = [day(2026, 1, 1), day(2025, 12, 31)]
        #expect(streak(decisions: decisions, now: day(2026, 1, 1)) == 2)
    }

    @Test func leapDayIsConsecutiveInALeapYear() {
        let decisions = [day(2028, 3, 1), day(2028, 2, 29), day(2028, 2, 28)]
        #expect(streak(decisions: decisions, now: day(2028, 3, 1)) == 3)
    }

    /// Photos exist on 29 Feb only in the given leap years, like the real library lookup.
    private func leapDayPhotos(inYears years: Set<Int>) -> @Sendable (Date) -> Bool {
        let cal = calendar
        return { date in
            let parts = cal.dateComponents([.year, .month, .day], from: date)
            guard parts.month == 2, parts.day == 29 else { return true }
            return years.contains { $0 <= parts.year! }
        }
    }

    private func leapStreak(year: Int, photoYears: Set<Int>) -> Int {
        let decisions = Set([day(year, 3, 1), day(year, 2, 28)].map { calendar.startOfDay(for: $0) })
        return DecisionStore.streak(decisionDays: decisions, hadPhotosOn: leapDayPhotos(inYears: photoYears),
                                    now: day(year, 3, 1), calendar: calendar)
    }

    @Test func leapDayWithPhotosFromAnEarlierLeapYearBreaksWhenMissed() {
        #expect(leapStreak(year: 2028, photoYears: [2024]) == 1)
    }

    @Test func leapDayWithNoPhotosYetIsBridged() {
        #expect(leapStreak(year: 2028, photoYears: []) == 2)
        #expect(leapStreak(year: 2020, photoYears: [2024]) == 2)
    }

    @Test func nonLeapYearHasNoLeapDayToBridgeOrBreak() {
        #expect(leapStreak(year: 2027, photoYears: [2024]) == 2)
    }

    @Test func photoChecksOnlyRunForMissedDaysAndStopAtTheOldestDecision() {
        final class Counter: @unchecked Sendable { var calls = 0 }
        let counter = Counter()
        let decisions = Set([day(2026, 3, 10), day(2026, 3, 8)].map { calendar.startOfDay(for: $0) })
        let result = DecisionStore.streak(
            decisionDays: decisions,
            hadPhotosOn: { _ in counter.calls += 1; return false },
            now: day(2026, 3, 10), calendar: calendar)
        #expect(result == 2)
        #expect(counter.calls == 1)
    }

    @Test func skipCapStopsRunawayLookups() {
        let decisions = Set([day(2026, 3, 10), day(2020, 1, 1)].map { calendar.startOfDay(for: $0) })
        let result = DecisionStore.streak(
            decisionDays: decisions, hadPhotosOn: { _ in false },
            now: day(2026, 3, 10), calendar: calendar, maxSkippedDays: 400)
        #expect(result == 1)
    }
}
