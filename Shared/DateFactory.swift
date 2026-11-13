import Foundation

nonisolated struct DateFactory {
    
    /// Generates a list of matching dates going back a specified number of years.
    /// - Parameters:
    ///   - calendar: The calendar instance to use (defaults to current).
    ///   - totalYears: How many years to look back (your yearOffset).
    ///   - now: The day to count back from. Tests pass a fixed date.
    /// - Returns: An array of calculated Date objects.
    static func generatePastDates(using calendar: Calendar = .current, totalYears: Int = 5, now: Date = .now) -> [Date] {
        let currentComponents = calendar.dateComponents([.day, .month, .year], from: now)
        var list = [Date]()
        
        guard let day = currentComponents.day,
              let month = currentComponents.month,
              let currentYear = currentComponents.year else {
            return list
        }
        
        for yearOffset in 0..<totalYears {
            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = currentYear - yearOffset
            
            // Skip years where the day doesn't exist (e.g. 29 Feb in a non-leap year)
            if let date = calendar.date(from: components),
               calendar.component(.day, from: date) == day,
               calendar.component(.month, from: date) == month {
                list.append(date)
            }
        }
        
        return list
    }
}
