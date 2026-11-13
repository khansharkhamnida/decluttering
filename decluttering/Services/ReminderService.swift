import UserNotifications

protocol ReminderScheduling: AnyObject {
    func isEnabled() async -> Bool
    func enable() async -> Bool
    func disable()
}

/// An optional daily nudge to open the booth.
final class ReminderService: ReminderScheduling {

    static let shared = ReminderService()

    private let center = UNUserNotificationCenter.current()
    private let identifier = "daily-booth-reminder"

    func isEnabled() async -> Bool {
        await center.pendingNotificationRequests().contains { $0.identifier == identifier }
    }

    func enable() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "The booth is open"
        content.body = "Today's memories are waiting. Snap, sort, bin: two minutes to a lighter phone."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 0), repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func disable() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
