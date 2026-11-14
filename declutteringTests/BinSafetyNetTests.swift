import Testing
import UIKit
@testable import decluttering

@MainActor
struct BinSafetyNetTests {

    // MARK: - Copy

    @Test func noticeSaysWhereThePhotosWent() {
        #expect(BoothVoice.binnedNotice(count: 1) == "Moved 1 photo to Recently Deleted. It stays there for about 30 days.")
        #expect(BoothVoice.binnedNotice(count: 4) == "Moved 4 photos to Recently Deleted. They stay there for about 30 days.")
        #expect(BoothVoice.photosURL?.absoluteString == "photos-redirect://")
    }

    // MARK: - On This Day

    private func onThisDay() -> (OnThisDayPresenter, MockOnThisDayView, MockInteractor, MockRouter, MockDecisions) {
        let view = MockOnThisDayView(), interactor = MockInteractor(), router = MockRouter(), decisions = MockDecisions()
        let defaults = UserDefaults(suiteName: "bin-safety-\(UUID().uuidString)")!
        let presenter = OnThisDayPresenter(view: view, interactor: interactor, router: router, decisions: decisions,
                                           reminders: MockReminders(), breaks: BreakPolicy(defaults: defaults))
        return (presenter, view, interactor, router, decisions)
    }

    private func sections(_ ids: [String]) -> [MemorySection] { [section(year: 2025, yearsAgo: 1, ids: ids)] }

    @Test func onThisDayNoticeFollowsASuccessfulBin() async {
        let (presenter, view, interactor, router, decisions) = onThisDay()
        interactor.sections = sections(["a", "b"])
        presenter.viewDidLoad()
        _ = await eventually { !view.sectionUpdates.isEmpty }
        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didSelect(id: "b")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.binnedCounts.isEmpty }

        #expect(view.binnedCounts == [2])
        #expect(view.celebrations.first?.contains("2 photos") == true)
        #expect(Set(decisions.binned) == ["a", "b"])
    }

    @Test func onThisDayShowsNoNoticeWhenCancelled() async {
        let (presenter, view, interactor, router, decisions) = onThisDay()
        interactor.deleteResult = .cancelled
        interactor.sections = sections(["a"])
        presenter.viewDidLoad()
        _ = await eventually { !view.sectionUpdates.isEmpty }
        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(view.binnedCounts.isEmpty)
        #expect(decisions.binned.isEmpty)
    }

    @Test func onThisDayShowsNoNoticeWhenDeleteFails() async {
        let (presenter, view, interactor, router, _) = onThisDay()
        interactor.deleteError = NSError(domain: "test", code: 1)
        interactor.sections = sections(["a"])
        presenter.viewDidLoad()
        _ = await eventually { !view.sectionUpdates.isEmpty }
        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.errors.isEmpty }

        #expect(view.binnedCounts.isEmpty)
    }

    @Test func onThisDayBinningNothingShowsNothing() async {
        let (presenter, view, interactor, router, _) = onThisDay()
        presenter.didTapBin()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(router.confirmedIDs.isEmpty)
        #expect(interactor.deletedIDs.isEmpty)
        #expect(view.binnedCounts.isEmpty)
    }

    // MARK: - Photo viewer

    private func viewer() -> (PhotoViewerPresenter, MockViewerView, MockInteractor, MockViewerRouter, MockDecisions) {
        let view = MockViewerView(), interactor = MockInteractor(), router = MockViewerRouter(), decisions = MockDecisions()
        let items = ["a", "b"].map { ViewerItem(id: $0, title: "2025", subtitle: "1 year ago") }
        let presenter = PhotoViewerPresenter(view: view, interactor: interactor, router: router, decisions: decisions,
                                             items: items, startIndex: 0, onChanged: {})
        return (presenter, view, interactor, router, decisions)
    }

    @Test func viewerNoticeFollowsASuccessfulBin() async {
        let (presenter, view, _, router, decisions) = viewer()
        presenter.viewDidLoad()
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.binnedCounts.isEmpty }

        #expect(view.binnedCounts == [1])
        #expect(view.celebrations.first?.contains("1 photo") == true)
        #expect(decisions.binned == ["a"])
    }

    @Test func viewerShowsNoNoticeWhenCancelledOrFailed() async {
        let (presenter, view, interactor, router, _) = viewer()
        interactor.deleteResult = .cancelled
        presenter.viewDidLoad()
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(view.binnedCounts.isEmpty)

        interactor.deleteResult = .deleted
        interactor.deleteError = NSError(domain: "test", code: 1)
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.errors.isEmpty }
        #expect(view.binnedCounts.isEmpty)
    }

    // MARK: - Swipe sort

    private func sorter() -> (SwipeSortPresenter, MockSortView, MockInteractor, MockSortRouter, MockDecisions) {
        let view = MockSortView(), interactor = MockInteractor(), router = MockSortRouter(), decisions = MockDecisions()
        let items = ["a", "b", "c"].map { ViewerItem(id: $0, title: "2025", subtitle: "1 year ago") }
        let policy = BreakPolicy(defaults: UserDefaults(suiteName: "bin-safety-\(UUID().uuidString)")!)
        let presenter = SwipeSortPresenter(view: view, interactor: interactor, router: router, decisions: decisions,
                                           breaks: policy, items: items, onFinished: {})
        return (presenter, view, interactor, router, decisions)
    }

    @Test func swipeSortNoticeFollowsASuccessfulBin() async {
        let (presenter, view, _, router, decisions) = sorter()
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        presenter.didDecide(.bin)
        presenter.didDecide(.keep)
        presenter.didTapBinPending()
        router.pendingConfirm?()
        _ = await eventually { !view.binnedCounts.isEmpty }

        #expect(view.binnedCounts == [2])
        #expect(Set(decisions.binned) == ["a", "b"])
    }

    @Test func swipeSortShowsNoNoticeWhenCancelledOrEmpty() async {
        let (presenter, view, interactor, router, _) = sorter()
        presenter.viewDidLoad()
        presenter.didTapBinPending()
        #expect(router.confirmed.isEmpty)

        interactor.deleteResult = .cancelled
        presenter.didDecide(.bin)
        presenter.didTapBinPending()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(view.binnedCounts.isEmpty)
    }
}
