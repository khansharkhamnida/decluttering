import AVFoundation
import Photos
import UIKit

final class PhotoViewerPresenter: PhotoViewerPresenterProtocol {

    private weak var view: PhotoViewerViewProtocol?
    private let interactor: PhotoViewerInteractorProtocol
    private let router: PhotoViewerRouterProtocol
    private let decisions: DecisionRecording
    private let onChanged: () -> Void

    private var items: [ViewerItem]
    private var index: Int

    init(view: PhotoViewerViewProtocol, interactor: PhotoViewerInteractorProtocol, router: PhotoViewerRouterProtocol,
         decisions: DecisionRecording, items: [ViewerItem], startIndex: Int, onChanged: @escaping () -> Void) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.items = items
        self.index = min(max(startIndex, 0), max(items.count - 1, 0))
        self.decisions = decisions
        self.onChanged = onChanged
    }

    func viewDidLoad() {
        view?.show(items: items, index: index)
        updateHeader()
    }

    func didChangePage(to newIndex: Int) {
        guard items.indices.contains(newIndex), newIndex != index else { return }
        index = newIndex
        updateHeader()
    }

    func didTapClose() { router.close() }

    func didTapBin() {
        guard items.indices.contains(index) else { return }
        let id = items[index].id
        router.confirmBin(ids: [id]) { [weak self] in self?.performBin(id) }
    }

    func didTapKeep() {
        guard items.indices.contains(index) else { return }
        let id = items[index].id
        decisions.recordKept(ids: [id])
        BoothHaptics.shared.sparkle()
        view?.showCelebration(text: BoothVoice.keepLine())
        removeItem(id)
    }

    private func performBin(_ id: String) {
        Task {
            do {
                // iOS shows its own confirmation and moves the photo to Recently Deleted
                guard try await interactor.delete(ids: [id]) == .deleted else { return }
                decisions.recordBinned(ids: [id])
                view?.showCelebration(text: BoothVoice.celebration(count: 1))
                removeItem(id)
            } catch {
                view?.showError(title: "Couldn't bin that one", message: error.localizedDescription)
            }
        }
    }

    private func removeItem(_ id: String) {
        items.removeAll { $0.id == id }
        onChanged()
        guard !items.isEmpty else { return router.close() }
        index = min(index, items.count - 1)
        view?.show(items: items, index: index)
        updateHeader()
    }

    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? {
        interactor.loadImage(id: id, targetSize: targetSize, completion: completion)
    }

    func cancelImage(_ token: ThumbnailToken) { interactor.cancelImage(token) }

    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken? {
        interactor.loadPlayerItem(id: id, completion: completion)
    }

    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken? {
        interactor.loadLivePhoto(id: id, targetSize: targetSize, completion: completion)
    }

    private func updateHeader() {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        view?.showHeader(title: item.title, subtitle: item.subtitle, counter: "\(index + 1) of \(items.count)")
    }
}
