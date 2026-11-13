import Testing
import UIKit
@testable import decluttering

@MainActor
final class MockViewerView: PhotoViewerViewProtocol {
    var shownItems: [[String]] = []
    var shownIndexes: [Int] = []
    var headers: [(title: String, counter: String)] = []
    var celebrations: [String] = []
    var errors: [String] = []

    func show(items: [ViewerItem], index: Int) { shownItems.append(items.map(\.id)); shownIndexes.append(index) }
    func showHeader(title: String, subtitle: String, counter: String) { headers.append((title, counter)) }
    func showError(title: String, message: String) { errors.append(title) }
    func showCelebration(text: String) { celebrations.append(text) }
}

@MainActor
final class MockViewerRouter: PhotoViewerRouterProtocol {
    var closed = 0
    var confirmed: [[String]] = []
    var pendingConfirm: (() -> Void)?
    func close() { closed += 1 }
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) { confirmed.append(ids); pendingConfirm = onConfirm }
}

@MainActor
struct PhotoViewerPresenterTests {

    let view = MockViewerView()
    let router = MockViewerRouter()
    let interactor = MockInteractor()
    let decisions = MockDecisions()
    let changes = ChangeCounter()

    final class ChangeCounter { var count = 0 }

    private func makePresenter(start: Int = 0) -> PhotoViewerPresenter {
        let counter = changes
        let items = [ViewerItem(id: "a", title: "2025", subtitle: "1 year ago"),
                     ViewerItem(id: "b", title: "2024", subtitle: "2 years ago"),
                     ViewerItem(id: "c", title: "2023", subtitle: "3 years ago")]
        return PhotoViewerPresenter(view: view, interactor: interactor, router: router, decisions: decisions,
                                    items: items, startIndex: start, onChanged: { counter.count += 1 })
    }

    @Test func opensOnTheRequestedPhotoWithACounter() {
        let presenter = makePresenter(start: 1)
        presenter.viewDidLoad()
        #expect(view.shownIndexes == [1])
        #expect(view.headers.last?.title == "2024")
        #expect(view.headers.last?.counter == "2 of 3")
    }

    @Test func aBadStartIndexIsClamped() {
        let presenter = makePresenter(start: 99)
        presenter.viewDidLoad()
        #expect(view.shownIndexes == [2])
    }

    @Test func swipingUpdatesTheHeader() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didChangePage(to: 2)
        #expect(view.headers.last?.counter == "3 of 3")
    }

    @Test func keepingRemovesThePhotoAndTellsTheGrid() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapKeep()

        #expect(decisions.kept == ["a"])
        #expect(view.shownItems.last == ["b", "c"])
        #expect(changes.count == 1)
        #expect(view.celebrations.count == 1)
    }

    @Test func binningConfirmsThenDeletes() async {
        let presenter = makePresenter(start: 1)
        presenter.viewDidLoad()
        presenter.didTapBin()

        #expect(router.confirmed == [["b"]])
        #expect(interactor.deletedIDs.isEmpty)
        router.pendingConfirm?()
        _ = await eventually { !view.celebrations.isEmpty }

        #expect(interactor.deletedIDs == [["b"]])
        #expect(decisions.binned == ["b"])
        #expect(view.shownItems.last == ["a", "c"])
        #expect(changes.count == 1)
    }

    @Test func cancellingTheSystemPromptKeepsThePhoto() async {
        interactor.deleteResult = .cancelled
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(decisions.binned.isEmpty)
        #expect(view.shownItems.last == ["a", "b", "c"])
    }

    @Test func removingTheLastPhotoClosesTheViewer() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapKeep()
        presenter.didTapKeep()
        presenter.didTapKeep()
        #expect(router.closed == 1)
    }

    @Test func aFailedDeleteShowsAnError() async {
        interactor.deleteError = NSError(domain: "test", code: 1)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.errors.isEmpty }
        #expect(view.errors.first == "Couldn't bin that one")
    }

    @Test func closeAsksTheRouter() {
        let presenter = makePresenter()
        presenter.didTapClose()
        #expect(router.closed == 1)
    }
}
