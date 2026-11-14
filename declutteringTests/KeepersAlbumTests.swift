import Foundation
import Testing
import UIKit
@testable import decluttering

@MainActor
final class MockKeepersAlbum: KeepersAlbumManaging {
    private(set) var added: [[String]] = []
    private(set) var removed: [[String]] = []
    func didKeep(ids: [String]) { added.append(ids) }
    func didUndoKeep(ids: [String]) { removed.append(ids) }
}

actor MockKeepersLibrary: KeepersAlbumLibrary {
    struct Failure: Error {}

    private(set) var adds: [(ids: [String], title: String, known: String?)] = []
    private(set) var removes: [(ids: [String], title: String, known: String?)] = []
    private let albumID: String?
    private let fails: Bool

    init(albumID: String? = "album-1", fails: Bool = false) {
        self.albumID = albumID
        self.fails = fails
    }

    func addToAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws -> String? {
        adds.append((assetIDs, title, knownAlbumID))
        if fails { throw Failure() }
        return albumID
    }

    func removeFromAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws {
        removes.append((assetIDs, title, knownAlbumID))
        if fails { throw Failure() }
    }
}

@MainActor
struct KeepersAlbumTests {

    private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "keepers-\(UUID().uuidString)")! }

    // MARK: Settings

    @Test func theSettingIsOnByDefaultAndRemembersTheChoice() {
        let settings = KeepersAlbumSettings(defaults: freshDefaults())
        #expect(settings.isEnabled)
        settings.isEnabled = false
        #expect(!settings.isEnabled)
        settings.isEnabled = true
        #expect(settings.isEnabled)
    }

    // MARK: Manager

    @Test func keepingAddsToTheKeepersAlbumAndRemembersIt() async {
        let library = MockKeepersLibrary()
        let settings = KeepersAlbumSettings(defaults: freshDefaults())
        let manager = KeepersAlbumManager(library: library, settings: settings)
        manager.didKeep(ids: ["a"])
        await manager.waitUntilIdle()
        let adds = await library.adds
        #expect(adds.count == 1)
        #expect(adds.first?.ids == ["a"])
        #expect(adds.first?.title == "Decluttering Keepers")
        #expect(adds.first?.known == nil)
        #expect(settings.albumID == "album-1")
    }

    @Test func theSavedAlbumIsReusedOnTheNextKeep() async {
        let library = MockKeepersLibrary()
        let manager = KeepersAlbumManager(library: library, settings: KeepersAlbumSettings(defaults: freshDefaults()))
        manager.didKeep(ids: ["a"])
        manager.didKeep(ids: ["b"])
        await manager.waitUntilIdle()
        let adds = await library.adds
        #expect(adds.map(\.ids) == [["a"], ["b"]])
        #expect(adds.last?.known == "album-1")
    }

    @Test func undoingRemovesFromTheAlbum() async {
        let library = MockKeepersLibrary()
        let manager = KeepersAlbumManager(library: library, settings: KeepersAlbumSettings(defaults: freshDefaults()))
        manager.didUndoKeep(ids: ["a"])
        await manager.waitUntilIdle()
        let removes = await library.removes
        #expect(removes.count == 1)
        #expect(removes.first?.ids == ["a"])
        #expect(removes.first?.title == "Decluttering Keepers")
    }

    @Test func settingOffMeansPhotosIsNeverTouched() async {
        let library = MockKeepersLibrary()
        let settings = KeepersAlbumSettings(defaults: freshDefaults())
        settings.isEnabled = false
        let manager = KeepersAlbumManager(library: library, settings: settings)
        manager.didKeep(ids: ["a"])
        manager.didUndoKeep(ids: ["a"])
        await manager.waitUntilIdle()
        #expect(await library.adds.isEmpty)
        #expect(await library.removes.isEmpty)
    }

    @Test func aFailingLibraryIsSilentAndLaterKeepsStillRun() async {
        let library = MockKeepersLibrary(fails: true)
        let settings = KeepersAlbumSettings(defaults: freshDefaults())
        let manager = KeepersAlbumManager(library: library, settings: settings)
        manager.didKeep(ids: ["a"])
        manager.didUndoKeep(ids: ["a"])
        manager.didKeep(ids: ["b"])
        await manager.waitUntilIdle()
        #expect(await library.adds.count == 2)
        #expect(await library.removes.count == 1)
        #expect(settings.albumID == nil)
    }

    @Test func emptyIdListsAreIgnored() async {
        let library = MockKeepersLibrary()
        let manager = KeepersAlbumManager(library: library, settings: KeepersAlbumSettings(defaults: freshDefaults()))
        manager.didKeep(ids: [])
        manager.didUndoKeep(ids: [])
        await manager.waitUntilIdle()
        #expect(await library.adds.isEmpty)
        #expect(await library.removes.isEmpty)
    }

    @Test func noAccessKeepsWorkingBecauseNothingIsStored() async {
        let library = MockKeepersLibrary(albumID: nil)
        let settings = KeepersAlbumSettings(defaults: freshDefaults())
        let manager = KeepersAlbumManager(library: library, settings: settings)
        manager.didKeep(ids: ["a"])
        await manager.waitUntilIdle()
        #expect(settings.albumID == nil)
    }

    // MARK: Presenters

    @Test func swipeSortKeepAddsAndUndoRemoves() {
        let album = MockKeepersAlbum()
        let decisions = MockDecisions()
        let presenter = SwipeSortPresenter(
            view: MockSortView(), interactor: MockInteractor(), router: MockSortRouter(), decisions: decisions,
            breaks: BreakPolicy(defaults: freshDefaults()),
            items: ["a", "b"].map { ViewerItem(id: $0, title: "2025", subtitle: "1 year ago") },
            onFinished: {}, keepersAlbum: album)
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        #expect(album.added == [["a"]])
        presenter.didDecide(.bin)
        #expect(album.added == [["a"]])
        presenter.didTapUndo()
        #expect(album.removed.isEmpty)
        presenter.didTapUndo()
        #expect(album.removed == [["a"]])
        #expect(decisions.keptLog == ["a"])
    }

    @Test func photoViewerKeepAddsToTheAlbum() {
        let album = MockKeepersAlbum()
        let decisions = MockDecisions()
        let presenter = PhotoViewerPresenter(
            view: MockViewerView(), interactor: MockInteractor(), router: MockViewerRouter(), decisions: decisions,
            items: [ViewerItem(id: "a", title: "2025", subtitle: "1 year ago")], startIndex: 0, onChanged: {},
            keepersAlbum: album)
        presenter.viewDidLoad()
        presenter.didTapKeep()
        #expect(album.added == [["a"]])
        #expect(decisions.keptLog == ["a"])
    }

    @Test func onThisDayKeepAddsToTheAlbum() {
        let album = MockKeepersAlbum()
        let decisions = MockDecisions()
        let presenter = OnThisDayPresenter(
            view: MockOnThisDayView(), interactor: MockInteractor(), router: MockRouter(), decisions: decisions,
            reminders: MockReminders(), breaks: BreakPolicy(defaults: freshDefaults()), keepersAlbum: album)
        presenter.didRequestKeep(id: "x")
        #expect(album.added == [["x"]])
        #expect(decisions.keptLog == ["x"])
    }

    @Test func resettingKeptPhotosLeavesTheAlbumAlone() {
        let album = MockKeepersAlbum()
        let router = MockRouter()
        let decisions = MockDecisions()
        let presenter = OnThisDayPresenter(
            view: MockOnThisDayView(), interactor: MockInteractor(), router: router, decisions: decisions,
            reminders: MockReminders(), breaks: BreakPolicy(defaults: freshDefaults()), keepersAlbum: album)
        presenter.didRequestKeep(id: "x")
        decisions.resetKept()
        #expect(album.removed.isEmpty)
    }
}
