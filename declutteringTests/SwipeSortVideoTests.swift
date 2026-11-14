import AVFoundation
import Photos
import Testing
import UIKit
@testable import decluttering

@MainActor
final class VideoSpyInteractor: PhotoViewerInteractorProtocol {
    private(set) var playerRequests: [String] = []
    private(set) var cancelled: [ThumbnailToken] = []
    private(set) var completions: [(AVPlayerItem?) -> Void] = []
    private var nextToken: ThumbnailToken = 100

    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? { nil }
    func cancelImage(_ token: ThumbnailToken) { cancelled.append(token) }
    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken? {
        playerRequests.append(id)
        completions.append(completion)
        nextToken += 1
        return nextToken
    }
    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken? { nil }
    func delete(ids: [String]) async throws -> DeleteResult { .deleted }
}

@MainActor
struct SwipeSortVideoTests {

    let interactor = VideoSpyInteractor()

    private func makePresenter(kinds: [MediaKind]) -> SwipeSortPresenter {
        let items = kinds.enumerated().map { ViewerItem(id: "i\($0.offset)", title: "2025", subtitle: "1 year ago", kind: $0.element) }
        return SwipeSortPresenter(view: MockSortView(), interactor: interactor, router: MockSortRouter(), decisions: MockDecisions(),
                                  breaks: BreakPolicy(defaults: UserDefaults(suiteName: "sort-video-\(UUID().uuidString)")!),
                                  items: items, onFinished: {})
    }

    private var autoplayOff: Bool {
        UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    @Test func presenterForwardsLoadVideoToTheInteractor() {
        let presenter = makePresenter(kinds: [.video])
        let token = presenter.loadVideo(id: "i0") { _ in }
        #expect(interactor.playerRequests == ["i0"])
        #expect(token == 101)
    }

    @Test func cancellingUsesTheImageTokenAPI() {
        let presenter = makePresenter(kinds: [.video])
        let token = presenter.loadVideo(id: "i0") { _ in }!
        presenter.cancelImage(token)
        #expect(interactor.cancelled == [token])
    }

    @Test func presenterNeverRequestsVideoOnItsOwn() {
        let presenter = makePresenter(kinds: [.photo, .livePhoto, .video])
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        presenter.didDecide(.bin)
        #expect(interactor.playerRequests.isEmpty)
    }

    private func makeCard(_ kind: MediaKind, id: String = "i0") -> SortCardView {
        let card = SortCardView()
        card.loadVideo = { [interactor] id, done in interactor.loadPlayerItem(id: id, completion: done) }
        card.cancelVideo = { [interactor] token in interactor.cancelImage(token) }
        card.configure(ViewerItem(id: id, title: "t", subtitle: "s", kind: kind), position: nil,
                       loader: { _, _, _ in nil }, cancel: { _ in })
        return card
    }

    @Test func photoCardsNeverRequestVideo() {
        let card = makeCard(.photo)
        card.setPlaying(true)
        #expect(interactor.playerRequests.isEmpty)
    }

    @Test(.enabled(if: !(UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled)))
    func videoCardRequestsOnceWhenPlayingAndCancelsWhenStopped() {
        let card = makeCard(.video)
        card.setPlaying(true)
        card.setPlaying(true)
        #expect(interactor.playerRequests == ["i0"])
        card.setPlaying(false)
        #expect(interactor.cancelled == [101])
    }

    @Test(.enabled(if: !(UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled)))
    func reusingACardCancelsItsPendingLoad() {
        let card = makeCard(.video)
        card.setPlaying(true)
        card.configure(ViewerItem(id: "other", title: "t", subtitle: "s"), position: nil, loader: { _, _, _ in nil }, cancel: { _ in })
        #expect(interactor.cancelled == [101])
        card.setPlaying(true)
        #expect(interactor.playerRequests == ["i0"])
    }

    @Test(.enabled(if: !(UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled)))
    func aLateLoadForACardThatMovedOnIsIgnored() {
        let card = makeCard(.video)
        card.setPlaying(true)
        card.setPlaying(false)
        // The cancelled request answers anyway; it must not revive playback
        interactor.completions[0](AVPlayerItem(url: URL(fileURLWithPath: "/dev/null")))
        card.setPlaying(true)
        #expect(interactor.playerRequests == ["i0", "i0"])
    }

    @Test func autoplayStaysOffWhenReduceMotionOrLowPowerIsOn() {
        guard autoplayOff else { return }
        let card = makeCard(.video)
        card.setPlaying(true)
        #expect(interactor.playerRequests.isEmpty)
    }
}
