import CoreHaptics
import UIKit

/// Little tactile moments: a crumple when photos are binned, a sparkle when one is kept.
final class BoothHaptics {

    static let shared = BoothHaptics()

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func crumple() {
        let events = (0..<6).map { index in
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1 - Float(index) * 0.13),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9 - Float(index) * 0.1)],
                          relativeTime: Double(index) * 0.045)
        }
        play(events) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    func sparkle() {
        let events = [(0.0, 0.4), (0.07, 0.6), (0.14, 0.9)].map { time, intensity in
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)],
                          relativeTime: time)
        }
        play(events) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func play(_ events: [CHHapticEvent], fallback: () -> Void) {
        guard supportsHaptics, let engine = makeEngine() else { return fallback() }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            fallback()
        }
    }

    private func makeEngine() -> CHHapticEngine? {
        if let engine { return engine }
        guard let created = try? CHHapticEngine() else { return nil }
        created.isAutoShutdownEnabled = true
        created.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? created.start()
        engine = created
        return created
    }
}
