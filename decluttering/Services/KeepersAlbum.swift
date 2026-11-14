import Foundation

/// Mirrors kept photos into an optional "Decluttering Keepers" album in Photos. Every call is best effort:
/// missing permission, limited access or a PhotoKit error is swallowed and never blocks keeping.
protocol KeepersAlbumManaging: AnyObject {
    func didKeep(ids: [String])
    func didUndoKeep(ids: [String])
}

/// Used when nothing should touch Photos (tests, previews).
final class NoOpKeepersAlbum: KeepersAlbumManaging {
    func didKeep(ids: [String]) {}
    func didUndoKeep(ids: [String]) {}
}

/// The on/off switch in the Booth report. On unless the person turned it off.
struct KeepersAlbumSettings {
    static let key = "keepersAlbumEnabled"
    static let albumIDKey = "keepersAlbumLocalID"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }

    var albumID: String? {
        get { defaults.string(forKey: Self.albumIDKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.albumIDKey) }
    }
}

/// The PhotoKit side, so the manager can be tested without a photo library.
protocol KeepersAlbumLibrary: Sendable {
    func addToAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws -> String?
    func removeFromAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws
}

extension PhotoLibraryService: KeepersAlbumLibrary {}

final class KeepersAlbumManager: KeepersAlbumManaging {

    static let albumTitle = "Decluttering Keepers"
    static let shared = KeepersAlbumManager()

    private let library: KeepersAlbumLibrary
    private let settings: KeepersAlbumSettings
    /// Changes run one after another so quick keeps can't create the album twice.
    private var tail: Task<Void, Never>?

    init(library: KeepersAlbumLibrary = PhotoLibraryService(), settings: KeepersAlbumSettings = KeepersAlbumSettings()) {
        self.library = library
        self.settings = settings
    }

    func didKeep(ids: [String]) {
        guard settings.isEnabled, !ids.isEmpty else { return }
        enqueue { [library, settings] in
            let id = try await library.addToAlbum(assetIDs: ids, title: Self.albumTitle, knownAlbumID: settings.albumID)
            if let id { settings.albumID = id }
        }
    }

    func didUndoKeep(ids: [String]) {
        guard settings.isEnabled, !ids.isEmpty else { return }
        enqueue { [library, settings] in
            try await library.removeFromAlbum(assetIDs: ids, title: Self.albumTitle, knownAlbumID: settings.albumID)
        }
    }

    /// Resolves once everything queued so far has finished.
    func waitUntilIdle() async { await tail?.value }

    private func enqueue(_ work: @escaping () async throws -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            try? await work()
        }
    }
}
