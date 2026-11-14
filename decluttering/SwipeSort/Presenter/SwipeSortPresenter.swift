import AVFoundation
import UIKit

/// Cards go by one at a time: keep is saved right away, bin is collected and confirmed once at the end.
final class SwipeSortPresenter: SwipeSortPresenterProtocol {

    private weak var view: SwipeSortViewProtocol?
    private let interactor: PhotoViewerInteractorProtocol
    private let router: SwipeSortRouterProtocol
    private let decisions: DecisionRecording
    private let breaks: BreakPolicy
    private let keepersAlbum: KeepersAlbumManaging
    private let onFinished: () -> Void

    private let items: [ViewerItem]
    private var index = 0
    private var history: [(item: ViewerItem, decision: SortDecision)] = []
    private var pendingBin: [String] = []
    private var keptCount = 0
    private var showingSummary = false

    init(view: SwipeSortViewProtocol, interactor: PhotoViewerInteractorProtocol, router: SwipeSortRouterProtocol,
         decisions: DecisionRecording, breaks: BreakPolicy, items: [ViewerItem], onFinished: @escaping () -> Void,
         keepersAlbum: KeepersAlbumManaging = NoOpKeepersAlbum()) {
        self.view = view
        self.keepersAlbum = keepersAlbum
        self.interactor = interactor
        self.router = router
        self.decisions = decisions
        self.breaks = breaks
        self.items = items
        self.onFinished = onFinished
    }

    func viewDidLoad() { render(.none) }

    func didDecide(_ decision: SortDecision) {
        guard index < items.count, !showingSummary else { return }
        let item = items[index]
        switch decision {
        case .keep:
            decisions.recordKept(ids: [item.id])
            keepersAlbum.didKeep(ids: [item.id])
            keptCount += 1
            BoothHaptics.shared.sparkle()
        case .bin:
            pendingBin.append(item.id)
            BoothHaptics.shared.tap()
        }
        history.append((item, decision))
        index += 1
        render(.forward)
        checkBreak()
    }

    /// Cards add up fast, so the reminder can come up in the middle of a stack. Photos waiting in the
    /// bin pile count too, since they were decided on just the same.
    private func checkBreak() {
        let count = decisions.todayCount() + pendingBin.count
        guard let level = breaks.nudge(forCount: count) else { return }
        router.showBreakReminder(level: level, count: count) { [weak self] in self?.didTapClose() }
    }

    func didTapUndo() {
        guard let last = history.popLast() else { return }
        switch last.decision {
        case .keep:
            decisions.removeKept(ids: [last.item.id])
            keepersAlbum.didUndoKeep(ids: [last.item.id])
            keptCount -= 1
        case .bin:
            pendingBin.removeAll { $0 == last.item.id }
        }
        index -= 1
        showingSummary = false
        render(.undo(last.decision))
    }

    /// ✕ with photos in the bin pile stops at the summary, so they can be binned without sorting the whole
    /// stack. With nothing waiting it goes home; kept photos are already saved and the pile is never deleted unasked.
    func didTapClose() {
        guard !showingSummary, !pendingBin.isEmpty else { return didTapFinish() }
        showingSummary = true
        render(.none)
    }

    func didTapKeepSorting() {
        guard showingSummary, index < items.count else { return }
        showingSummary = false
        render(.none)
    }

    func didTapFinish() {
        onFinished()
        router.close()
    }

    func didTapBinPending() {
        let ids = pendingBin
        guard !ids.isEmpty else { return }
        router.confirmBin(ids: ids) { [weak self] in self?.performBin(ids) }
    }

    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? {
        interactor.loadImage(id: id, targetSize: targetSize, completion: completion)
    }

    func cancelImage(_ token: ThumbnailToken) { interactor.cancelImage(token) }

    /// Only the front card asks for this, and only when it is a video. Cancel with `cancelImage`.
    func loadVideo(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken? {
        interactor.loadPlayerItem(id: id, completion: completion)
    }

    private func performBin(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        Task {
            do {
                guard try await interactor.delete(ids: ids) == .deleted else { return }
                decisions.recordBinned(ids: ids)
                pendingBin.removeAll()
                view?.showCelebration(text: BoothVoice.celebration(count: ids.count))
                view?.showBinned(count: ids.count)
                onFinished()
                try? await Task.sleep(for: .seconds(1.4))
                router.close()
            } catch {
                view?.showError(title: "Couldn't bin those", message: error.localizedDescription)
            }
        }
    }

    private func render(_ transition: SortTransition) {
        if showingSummary || index >= items.count {
            showingSummary = true
            view?.show(summary: SortSummary(kept: keptCount, toBin: pendingBin.count, remaining: items.count - index))
            return
        }
        view?.show(front: items[index],
                   back: items.indices.contains(index + 1) ? items[index + 1] : nil,
                   position: "\(index + 1) of \(items.count)",
                   canUndo: !history.isEmpty,
                   transition: transition)
    }
}
