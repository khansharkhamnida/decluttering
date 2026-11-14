import Photos
import PhotosUI
import UIKit

final class OnThisDayRouter: OnThisDayRouterProtocol {

    private weak var viewController: (UIViewController & OnThisDayViewProtocol)?
    private var thumbnailLoader: ThumbnailLoader?

    static func makeModule() -> UIViewController {
        let view = OnThisDayViewController()
        let interactor = OnThisDayInteractor()
        let router = OnThisDayRouter()
        let presenter = OnThisDayPresenter(view: view, interactor: interactor, router: router,
                                       decisions: DecisionStore.shared, reminders: ReminderService.shared,
                                       breaks: BreakPolicy(), keepersAlbum: KeepersAlbumManager.shared)
        view.presenter = presenter
        router.viewController = view
        router.thumbnailLoader = { id, size, done in interactor.loadThumbnail(id: id, targetSize: size, completion: done) }
        let navigation = UINavigationController(rootViewController: view)
        navigation.overrideUserInterfaceStyle = BoothTheme.interfaceStyle
        return navigation
    }

    func openViewer(items: [ViewerItem], startIndex: Int, interactor: PhotoViewerInteractorProtocol,
                    onChanged: @escaping () -> Void) {
        guard let host = viewController else { return }
        let viewer = PhotoViewerRouter.makeModule(
            items: items, startIndex: startIndex, interactor: interactor, onChanged: onChanged,
            sourceViewProvider: { [weak host] id in host?.thumbnailView(for: id) })
        host.present(viewer, animated: true)
    }

    func showYearPicker(dateText: String, options: [YearOption], onPick: @escaping (YearChoice) -> Void) {
        guard let host = viewController else { return }
        YearPickerViewController.present(from: host, dateText: dateText, options: options, onPick: onPick)
    }

    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void) {
        guard let host = viewController else { return }
        BreakReminderViewController.present(from: host, level: level, count: count) { [weak host] in
            // Also leaves the photo viewer or swipe sort if the reminder came up over one of them
            if host?.presentedViewController != nil { host?.dismiss(animated: true) }
            onBreak()
        }
    }

    func openSwipeSort(items: [ViewerItem], interactor: PhotoViewerInteractorProtocol, onFinished: @escaping () -> Void) {
        guard let host = viewController else { return }
        host.present(SwipeSortRouter.makeModule(items: items, interactor: interactor, onFinished: onFinished), animated: true)
    }

    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) {
        guard let host = viewController, let loader = thumbnailLoader else { return onConfirm() }
        LastLookViewController.present(from: host, ids: ids, loader: loader, onConfirm: onConfirm)
    }

    func openStats(stats: BoothStats, earnedStickers: Set<String>, reminderOn: Bool,
                   onToggleReminder: @escaping (Bool, @escaping (Bool) -> Void) -> Void,
                   onResetKept: @escaping () -> Void) {
        guard let host = viewController else { return }
        StatsViewController.present(from: host, stats: stats, earnedStickers: earnedStickers, reminderOn: reminderOn,
                                    onToggleReminder: onToggleReminder, onResetKept: onResetKept)
    }

    func showLimitedOptions(onPickerFinished: @escaping () -> Void) {
        guard let host = viewController else { return }
        let sheet = UIAlertController(title: "Binny only sees some photos",
                                      message: "Pick which photos Binny can see, or allow your whole library.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Choose more photos", style: .default) { _ in
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: host) { _ in onPickerFinished() }
        })
        sheet.addAction(UIAlertAction(title: "Allow Full Access in Settings", style: .default) { [weak self] _ in self?.openSettings() })
        sheet.addAction(UIAlertAction(title: "Not now", style: .cancel))
        sheet.popoverPresentationController?.sourceView = host.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
        host.present(sheet, animated: true)
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
