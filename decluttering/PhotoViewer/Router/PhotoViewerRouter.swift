import UIKit

final class PhotoViewerRouter: PhotoViewerRouterProtocol {

    private weak var viewController: UIViewController?
    private var imageLoader: ThumbnailLoader?

    /// `sourceViewProvider` returns the thumbnail a photo grows out of (and shrinks back into).
    static func makeModule(items: [ViewerItem], startIndex: Int, interactor: PhotoViewerInteractorProtocol,
                           onChanged: @escaping () -> Void,
                           sourceViewProvider: @escaping (String) -> UIView?) -> UIViewController {
        let view = PhotoViewerViewController()
        let router = PhotoViewerRouter()
        let presenter = PhotoViewerPresenter(view: view, interactor: interactor, router: router,
                                             decisions: DecisionStore.shared, items: items, startIndex: startIndex, onChanged: onChanged)
        view.presenter = presenter
        router.viewController = view
        router.imageLoader = { id, size, done in interactor.loadImage(id: id, targetSize: size, completion: done) }

        view.modalPresentationStyle = .fullScreen
        view.preferredTransition = .zoom { context in
            guard let viewer = context.zoomedViewController as? PhotoViewerViewController,
                  let id = viewer.currentID else { return nil }
            return sourceViewProvider(id)
        }
        return view
    }

    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) {
        guard let host = viewController, let loader = imageLoader else { return onConfirm() }
        LastLookViewController.present(from: host, ids: ids, loader: loader, onConfirm: onConfirm)
    }

    func close() {
        viewController?.dismiss(animated: true)
    }
}
