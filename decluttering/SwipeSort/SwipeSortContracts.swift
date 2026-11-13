import UIKit

enum SortDecision {
    case keep
    case bin
}

enum SortTransition {
    case none
    case forward
    case undo(SortDecision)
}

struct SortSummary {
    let kept: Int
    let toBin: Int
    let remaining: Int
}

// MARK: - View

protocol SwipeSortViewProtocol: AnyObject {
    func show(front: ViewerItem, back: ViewerItem?, position: String, canUndo: Bool, transition: SortTransition)
    func show(summary: SortSummary)
    func showCelebration(text: String)
    func showError(title: String, message: String)
}

// MARK: - Presenter

protocol SwipeSortPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didDecide(_ decision: SortDecision)
    func didTapUndo()
    func didTapClose()
    func didTapKeepSorting()
    func didTapBinPending()
    func didTapFinish()
    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?
    func cancelImage(_ token: ThumbnailToken)
}

// MARK: - Router

protocol SwipeSortRouterProtocol: AnyObject {
    func close()
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void)
    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void)
}
