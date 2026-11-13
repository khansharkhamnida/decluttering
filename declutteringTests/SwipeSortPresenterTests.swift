import Testing
import UIKit
@testable import decluttering

@MainActor
final class MockSortView: SwipeSortViewProtocol {
    var fronts: [String] = []
    var backs: [String?] = []
    var positions: [String] = []
    var undoStates: [Bool] = []
    var transitions: [SortTransition] = []
    var summaries: [SortSummary] = []
    var celebrations: [String] = []
    var errors: [String] = []

    func show(front: ViewerItem, back: ViewerItem?, position: String, canUndo: Bool, transition: SortTransition) {
        fronts.append(front.id); backs.append(back?.id); positions.append(position); undoStates.append(canUndo); transitions.append(transition)
    }
    func show(summary: SortSummary) { summaries.append(summary) }
    func showCelebration(text: String) { celebrations.append(text) }
    func showError(title: String, message: String) { errors.append(title) }
}

@MainActor
final class MockSortRouter: SwipeSortRouterProtocol {
    var closed = 0
    var confirmed: [[String]] = []
    var pendingConfirm: (() -> Void)?
    func close() { closed += 1 }
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) { confirmed.append(ids); pendingConfirm = onConfirm }
    var breaks: [(level: BreakLevel, count: Int)] = []
    var breakAction: (() -> Void)?
    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void) { breaks.append((level, count)); breakAction = onBreak }
}

@MainActor
struct SwipeSortPresenterTests {

    let view = MockSortView()
    let router = MockSortRouter()
    let interactor = MockInteractor()
    let decisions = MockDecisions()
    var finished = FinishCounter()
    let policy = BreakPolicy(defaults: UserDefaults(suiteName: "sort-breaks-\(UUID().uuidString)")!)

    final class FinishCounter { var count = 0 }

    private func makePresenter(ids: [String] = ["a", "b", "c"]) -> SwipeSortPresenter {
        let counter = finished
        let items = ids.map { ViewerItem(id: $0, title: "2025", subtitle: "1 year ago") }
        return SwipeSortPresenter(view: view, interactor: interactor, router: router, decisions: decisions, breaks: policy,
                                  items: items, onFinished: { counter.count += 1 })
    }

    @Test func startsOnTheFirstCardWithTheNextBehindIt() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        #expect(view.fronts == ["a"])
        #expect(view.backs == ["b"])
        #expect(view.positions == ["1 of 3"])
        #expect(view.undoStates == [false])
    }

    @Test func keepIsSavedImmediately() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didDecide(.keep)

        #expect(decisions.kept == ["a"])
        #expect(view.fronts.last == "b")
        #expect(view.undoStates.last == true)
    }

    @Test func binOnlyJoinsThePileUntilConfirmed() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didDecide(.bin)

        #expect(interactor.deletedIDs.isEmpty)
        #expect(decisions.binned.isEmpty)
        #expect(view.fronts.last == "b")
    }

    @Test func undoRestoresTheCardAndUndoesAKeep() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        presenter.didTapUndo()

        #expect(decisions.kept.isEmpty)
        #expect(view.fronts.last == "a")
        #expect(view.positions.last == "1 of 3")
        if case .undo(let decision) = view.transitions.last { #expect(decision == .keep) } else { Issue.record("expected an undo transition") }
    }

    @Test func undoRemovesAPhotoFromTheBinPile() async {
        let presenter = makePresenter(ids: ["a", "b"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        presenter.didDecide(.keep)
        presenter.didTapUndo()
        presenter.didTapUndo()
        presenter.didDecide(.keep)
        presenter.didDecide(.keep)

        #expect(view.summaries.last?.toBin == 0)
        #expect(view.summaries.last?.kept == 2)
    }

    @Test func undoWithNothingDoneDoesNothing() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapUndo()
        #expect(view.fronts.count == 1)
    }

    @Test func finishingTheStackShowsASummary() {
        let presenter = makePresenter(ids: ["a", "b", "c"])
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        presenter.didDecide(.bin)
        presenter.didDecide(.bin)

        let summary = view.summaries.last
        #expect(summary?.kept == 1)
        #expect(summary?.toBin == 2)
        #expect(summary?.remaining == 0)
    }

    @Test func closingAlwaysGoesStraightHome() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        presenter.didTapClose()

        #expect(router.closed == 1)
        #expect(finished.count == 1)
        #expect(decisions.binned.isEmpty)
        #expect(interactor.deletedIDs.isEmpty)
    }

    @Test func closingFromTheSummaryAlsoGoesHome() {
        let presenter = makePresenter(ids: ["a"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        #expect(view.summaries.last?.remaining == 0)

        presenter.didTapClose()
        #expect(router.closed == 1)
    }

    @Test func closingWithNothingPendingJustCloses() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        presenter.didTapClose()

        #expect(router.closed == 1)
        #expect(finished.count == 1)
    }

    @Test func swipesAreIgnoredWhileTheSummaryIsShowing() {
        let presenter = makePresenter(ids: ["a"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        #expect(view.summaries.last?.remaining == 0)
        presenter.didDecide(.keep)

        #expect(decisions.kept.isEmpty)
    }

    @Test func binningThePileConfirmsThenDeletesThenCloses() async {
        let presenter = makePresenter(ids: ["a", "b"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        presenter.didDecide(.bin)
        presenter.didTapBinPending()

        #expect(router.confirmed == [["a", "b"]])
        router.pendingConfirm?()
        _ = await eventually(timeout: 5) { router.closed == 1 }

        #expect(interactor.deletedIDs == [["a", "b"]])
        #expect(decisions.binned == ["a", "b"])
        #expect(view.celebrations.count == 1)
        #expect(finished.count == 1)
    }

    @Test func aCancelledDeleteLeavesThePileAlone() async {
        interactor.deleteResult = .cancelled
        let presenter = makePresenter(ids: ["a"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        presenter.didTapBinPending()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(decisions.binned.isEmpty)
        #expect(router.closed == 0)
        #expect(view.summaries.last?.toBin == 1)
    }

    @Test func theBreakReminderCanAppearInTheMiddleOfAStack() {
        decisions.earlierToday = BreakPolicy.gentleAt - 1
        let presenter = makePresenter(ids: ["a", "b", "c"])
        presenter.viewDidLoad()
        presenter.didDecide(.keep)

        #expect(router.breaks.first?.level == .gentle)
        #expect(router.breaks.first?.count == BreakPolicy.gentleAt)
        #expect(view.fronts.last == "b")
    }

    @Test func photosInTheBinPileCountTowardsTheBreak() {
        decisions.earlierToday = BreakPolicy.gentleAt - 2
        let presenter = makePresenter(ids: ["a", "b", "c"])
        presenter.viewDidLoad()
        presenter.didDecide(.bin)
        #expect(router.breaks.isEmpty)
        presenter.didDecide(.bin)
        #expect(router.breaks.first?.count == BreakPolicy.gentleAt)
    }

    @Test func carryingOnDoesNotAskAgainAtTheSameLevel() {
        decisions.earlierToday = BreakPolicy.gentleAt - 1
        let presenter = makePresenter(ids: ["a", "b", "c"])
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        presenter.didDecide(.keep)
        presenter.didDecide(.keep)
        #expect(router.breaks.count == 1)
    }

    @Test func takingTheBreakGoesHome() {
        decisions.earlierToday = BreakPolicy.gentleAt - 1
        let presenter = makePresenter(ids: ["a", "b"])
        presenter.viewDidLoad()
        presenter.didDecide(.keep)
        router.breakAction?()

        #expect(router.closed == 1)
        #expect(finished.count == 1)
    }
}
