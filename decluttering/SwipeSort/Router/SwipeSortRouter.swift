import UIKit

final class SwipeSortRouter: SwipeSortRouterProtocol {

    private weak var viewController: UIViewController?
    private var imageLoader: ThumbnailLoader?

    static func makeModule(items: [ViewerItem], interactor: PhotoViewerInteractorProtocol,
                           onFinished: @escaping () -> Void) -> UIViewController {
        let view = SwipeSortViewController()
        let router = SwipeSortRouter()
        let presenter = SwipeSortPresenter(view: view, interactor: interactor, router: router,
                                           decisions: DecisionStore.shared, breaks: BreakPolicy(),
                                           items: items, onFinished: onFinished)
        view.presenter = presenter
        router.viewController = view
        router.imageLoader = { id, size, done in interactor.loadImage(id: id, targetSize: size, completion: done) }
        view.modalPresentationStyle = .fullScreen
        return view
    }

    func close() {
        viewController?.dismiss(animated: true)
    }

    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void) {
        guard let host = viewController else { return }
        BreakReminderViewController.present(from: host, level: level, count: count, onBreak: onBreak)
    }

    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) {
        guard let host = viewController, let loader = imageLoader else { return onConfirm() }
        LastLookViewController.present(from: host, ids: ids, loader: loader, onConfirm: onConfirm)
    }
}
