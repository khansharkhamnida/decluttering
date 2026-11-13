import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import decluttering

// MARK: - Stickers

@MainActor
struct StickerBookTests {

    private func freshDefaults() -> UserDefaults {
        let name = "stickers-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func nothingIsEarnedAtTheStart() {
        let earned = StickerBook.earnedIDs(for: BoothStats(binned: 0, kept: 0, streak: 0), defaults: freshDefaults())
        #expect(earned.isEmpty)
    }

    @Test func thresholdsUnlockTheRightStickers() {
        let earned = StickerBook.earnedIDs(for: BoothStats(binned: 10, kept: 1, streak: 3), defaults: freshDefaults())
        #expect(earned == ["first-poof", "first-keeper", "three-day", "tidy-ten"])
    }

    @Test func everyStickerIsEarnableAndIDsAreUnique() {
        let everything = BoothStats(binned: 1000, kept: 1000, streak: 365)
        let earned = StickerBook.earnedIDs(for: everything, defaults: freshDefaults())
        #expect(earned.count == StickerBook.all.count)
        #expect(Set(StickerBook.all.map(\.id)).count == StickerBook.all.count)
    }

    @Test func eachStickerIsAnnouncedOnlyOnce() {
        let defaults = freshDefaults()
        let stats = BoothStats(binned: 1, kept: 0, streak: 1)
        #expect(StickerBook.newlyEarned(for: stats, defaults: defaults).map(\.id) == ["first-poof"])
        #expect(StickerBook.newlyEarned(for: stats, defaults: defaults).isEmpty)
        #expect(StickerBook.newlyEarned(for: BoothStats(binned: 10, kept: 0, streak: 1), defaults: defaults).map(\.id) == ["tidy-ten"])
    }

    @Test func aBrokenStreakKeepsItsSticker() {
        let defaults = freshDefaults()
        _ = StickerBook.newlyEarned(for: BoothStats(binned: 0, kept: 0, streak: 7), defaults: defaults)
        let later = StickerBook.earnedIDs(for: BoothStats(binned: 0, kept: 0, streak: 0), defaults: defaults)
        #expect(later.contains("week-wonder"))
        #expect(later.contains("three-day"))
    }
}

// MARK: - Words

struct BoothVoiceTests {

    @Test func quoteOfTheDayIsStableWithinADayAndChangesAcrossDays() {
        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        #expect(BoothVoice.quoteOfTheDay(date: day1, calendar: calendar) == BoothVoice.quoteOfTheDay(date: day1, calendar: calendar))
        #expect(BoothVoice.quoteOfTheDay(date: day1, calendar: calendar) != BoothVoice.quoteOfTheDay(date: day2, calendar: calendar))
    }

    @Test func randomQuoteNeverRepeatsTheCurrentOne() {
        let current = BoothVoice.quotes[0]
        for _ in 0..<50 { #expect(BoothVoice.randomQuote(excluding: current) != current) }
    }

    @Test func celebrationsGetThePluralRight() {
        #expect(BoothVoice.celebration(count: 1).contains("1 photo") && !BoothVoice.celebration(count: 1).contains("1 photos"))
        #expect(BoothVoice.celebration(count: 5).contains("5 photos"))
    }

    @Test func reportLineFollowsTheStreak() {
        #expect(BoothVoice.reportLine(binned: 0, streak: 0).contains("first bin"))
        #expect(BoothVoice.reportLine(binned: 5, streak: 0).contains("light the streak"))
        #expect(BoothVoice.reportLine(binned: 5, streak: 1).contains("Day one"))
        #expect(BoothVoice.reportLine(binned: 5, streak: 4).contains("4 days"))
        #expect(BoothVoice.reportLine(binned: 5, streak: 20).contains("legend"))
    }

    @Test func thereIsPlentyToSay() {
        #expect(BoothVoice.quotes.count >= 15)
        #expect(Set(BoothVoice.quotes).count == BoothVoice.quotes.count)
        #expect(BoothVoice.lastLookQuestions.isEmpty == false)
    }

    @Test func restLinesFitTheBubble() {
        for line in BoothVoice.restLines { #expect(line.count <= BoothVoice.maxLineLength) }
        #expect(BoothVoice.restLines.count >= 3)
    }

    @Test func breakCopyMentionsTheCountAndChangesWithTheLevel() {
        let gentle = BoothVoice.breakCopy(level: .gentle, count: 42)
        let rest = BoothVoice.breakCopy(level: .rest, count: 120)
        #expect(gentle.body.contains("42"))
        #expect(rest.body.contains("120"))
        #expect(gentle.title != rest.title)
        #expect(gentle.primary != rest.primary)
    }

    @Test func everyLineBinnyCanSayFitsTheBubble() {
        let celebrations = [1, 5, 250].map { BoothVoice.celebration(count: $0) }
        let lines = BoothVoice.quotes + BoothVoice.keepLines + celebrations
        for line in lines { #expect(line.count <= BoothVoice.maxLineLength, "\(line)") }
        for _ in 0..<50 {
            for count in [1, 5, 250] { #expect(BoothVoice.celebration(count: count).count <= BoothVoice.maxLineLength) }
        }
    }
}

// MARK: - Dates

struct DateFactoryTests {

    private let calendar = Calendar(identifier: .gregorian)

    @Test func sameDayInEachPastYear() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13))!
        let dates = DateFactory.generatePastDates(using: calendar, totalYears: 4, now: today)
        let parts = dates.map { calendar.dateComponents([.year, .month, .day], from: $0) }
        #expect(parts.map(\.year) == [2026, 2025, 2024, 2023])
        #expect(parts.allSatisfy { $0.month == 11 && $0.day == 13 })
    }

    @Test func leapDayOnlyAppearsInLeapYears() {
        let leapDay = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29))!
        let dates = DateFactory.generatePastDates(using: calendar, totalYears: 5, now: leapDay)
        let years = dates.map { calendar.component(.year, from: $0) }
        #expect(years == [2028, 2024])
        #expect(dates.allSatisfy { calendar.component(.day, from: $0) == 29 })
    }
}

// MARK: - Break policy

struct BreakPolicyTests {

    private func policy() -> BreakPolicy {
        BreakPolicy(defaults: UserDefaults(suiteName: "policy-\(UUID().uuidString)")!, calendar: Calendar(identifier: .gregorian))
    }

    private let morning = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 9))!
    private let nextDay = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9))!

    @Test func levelsFollowTheThresholds() {
        #expect(BreakPolicy.level(forCount: 0) == .none)
        #expect(BreakPolicy.level(forCount: BreakPolicy.gentleAt - 1) == .none)
        #expect(BreakPolicy.level(forCount: BreakPolicy.gentleAt) == .gentle)
        #expect(BreakPolicy.level(forCount: BreakPolicy.restAt - 1) == .gentle)
        #expect(BreakPolicy.level(forCount: BreakPolicy.restAt) == .rest)
    }

    @Test func nothingBelowTheFirstThreshold() {
        #expect(policy().nudge(forCount: BreakPolicy.gentleAt - 1, now: morning) == nil)
    }

    @Test func eachLevelFiresOnceAndInOrder() {
        let policy = policy()
        #expect(policy.nudge(forCount: BreakPolicy.gentleAt, now: morning) == .gentle)
        #expect(policy.nudge(forCount: BreakPolicy.gentleAt + 1, now: morning) == nil)
        #expect(policy.nudge(forCount: BreakPolicy.restAt, now: morning) == .rest)
        #expect(policy.nudge(forCount: BreakPolicy.restAt + 50, now: morning) == nil)
    }

    @Test func jumpingPastBothGivesOnlyTheStrongerOne() {
        let policy = policy()
        #expect(policy.nudge(forCount: BreakPolicy.restAt + 30, now: morning) == .rest)
        #expect(policy.nudge(forCount: BreakPolicy.restAt + 31, now: morning) == nil)
    }

    @Test func aNewDayStartsFresh() {
        let policy = policy()
        #expect(policy.nudge(forCount: BreakPolicy.gentleAt, now: morning) == .gentle)
        #expect(policy.nudge(forCount: BreakPolicy.gentleAt, now: nextDay) == .gentle)
    }

    @Test func theMemoryLivesInStorageSoRelaunchesDoNotRepeatIt() {
        let defaults = UserDefaults(suiteName: "policy-\(UUID().uuidString)")!
        let calendar = Calendar(identifier: .gregorian)
        #expect(BreakPolicy(defaults: defaults, calendar: calendar).nudge(forCount: BreakPolicy.gentleAt, now: morning) == .gentle)
        #expect(BreakPolicy(defaults: defaults, calendar: calendar).nudge(forCount: BreakPolicy.gentleAt + 1, now: morning) == nil)
    }
}
