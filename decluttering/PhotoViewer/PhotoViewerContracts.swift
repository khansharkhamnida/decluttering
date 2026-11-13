import AVFoundation
import Photos
import UIKit

struct ViewerItem {
    let id: String
    let title: String
    let subtitle: String
    var kind: MediaKind = .photo
}

// MARK: - Interactor (implemented by the photo library layer)

protocol PhotoViewerInteractorProtocol: AnyObject {
    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?
    func cancelImage(_ token: ThumbnailToken)
    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken?
    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken?
    func delete(ids: [String]) async throws -> DeleteResult
}

// MARK: - View

protocol PhotoViewerViewProtocol: AnyObject {
    func show(items: [ViewerItem], index: Int)
    func showHeader(title: String, subtitle: String, counter: String)
    func showError(title: String, message: String)
    func showCelebration(text: String)
}

// MARK: - Presenter

protocol PhotoViewerPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didChangePage(to index: Int)
    func didTapClose()
    func didTapBin()
    func didTapKeep()
    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?
    func cancelImage(_ token: ThumbnailToken)
    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken?
    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken?
}

// MARK: - Router

protocol PhotoViewerRouterProtocol: AnyObject {
    func close()
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void)
}
