import Foundation

/// Everything Binny says. All lines are written for this app.
nonisolated enum BoothVoice {

    static let maxLineLength = 68

    static let quotes: [String] = [
        "Every photo you let go makes room for a memory that sparkles.",
        "A tidy gallery is a deep breath you can scroll.",
        "Decluttering your phone is just fluffing the pillows of your mind.",
        "You don't need fourteen sunsets. Keep the one that made you gasp.",
        "Clutter is yesterday asking for attention. Say thanks, wave goodbye.",
        "Your camera roll is a garden. Weed gently, water the good ones.",
        "Be the curator, not the storage unit.",
        "Less scrolling, more glowing.",
        "Tiny tidy-ups, big soft sighs.",
        "A little bin a day keeps the storage warning away.",
        "Photos are for remembering, not for hoarding.",
        "Clean gallery, quiet mind, happy thumbs.",
        "Your best memories hide under nine thousand others. Let them out.",
        "Blurry? Duplicate? Screenshot of a screenshot? Bye, little pixel.",
        "Not every moment needs a backup. Some just needed to be lived.",
        "Keep the ones that make you smile. Thank the rest and let them go.",
        "Future you will love a lighter pocket.",
        "Space is a gift you can give your own memories.",
        "Letting go is just making room for the next good thing.",
        "One tidy corner of your phone can make a whole day feel softer."
    ]

    static let lastLookQuestions: [String] = [
        "Are you sure you really need these?",
        "Will future you ever scroll back to this?",
        "Is this a memory, or just a very big file?",
        "Does this one make you smile, or just take up space?",
        "Be honest: have you looked at this since the day you took it?",
        "Is this the best of the batch, or just one of many?",
        "Would you frame it? Would you miss it? Really?"
    ]

    static let keepLines: [String] = [
        "Kept! Excellent taste.",
        "Into the keeper pile it goes.",
        "A true favourite. Binny approves.",
        "Kept, and it won't ask again."
    ]

    /// Said when someone opens the booth after a very big day of sorting.
    static let restLines: [String] = [
        "Big day of tidying! Rest is part of decluttering too.",
        "Plenty sorted today. Your photos will wait for you.",
        "A rested mind picks better keepers. See you tomorrow!"
    ]

    static func restLine() -> String { restLines.randomElement() ?? restLines[0] }

    struct BreakCopy {
        let title: String
        let body: String
        let primary: String
        let secondary: String
    }

    static func breakCopy(level: BreakLevel, count: Int) -> BreakCopy {
        switch level {
        case .rest:
            return BreakCopy(title: "That's plenty for today!",
                             body: "\(count) photos is a big day. Your gallery will still be here tomorrow, and a rested mind decides better.",
                             primary: "Done for today", secondary: "Keep going anyway")
        default:
            return BreakCopy(title: "Time for a little break?",
                             body: "You've sorted \(count) photos today. Decluttering is best in small doses, so stretch, sip some water and come back fresh.",
                             primary: "Take a break", secondary: "Keep going")
        }
    }

    static func quoteOfTheDay(date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return quotes[day % quotes.count]
    }

    static func randomQuote(excluding current: String? = nil) -> String {
        let pool = quotes.filter { $0 != current }
        return pool.randomElement() ?? quotes[0]
    }

    static func lastLookQuestion() -> String {
        lastLookQuestions.randomElement() ?? lastLookQuestions[0]
    }

    static func keepLine() -> String {
        keepLines.randomElement() ?? keepLines[0]
    }

    static func celebration(count: Int) -> String {
        let photos = count == 1 ? "1 photo" : "\(count) photos"
        let lines = [
            "Poof! \(photos) gone. Your gallery just exhaled.",
            "\(photos) fewer. One deep breath lighter.",
            "Bye-bye, \(photos). Thanks for the memories!",
            "Tidied \(photos). Your future self says thanks."
        ]
        return lines.randomElement() ?? lines[0]
    }

    static func reportLine(binned: Int, streak: Int) -> String {
        switch (binned, streak) {
        case (0, _): return "Your very first bin starts the streak."
        case (_, 0): return "Bin or keep one photo today to light the streak again."
        case (_, 1): return "Day one of the streak. Tiny steps count."
        case (_, 2...6): return "\(streak) days in a row. Binny is doing a little dance."
        default: return "\(streak) days in a row! You are officially a tidy legend."
        }
    }
}
