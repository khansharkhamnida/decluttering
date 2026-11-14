import UIKit

typealias ThumbnailToken = Int32

// MARK: - View models (what the View needs, already formatted)

enum ItemBadge: Equatable {
    case none
    case live
    case video(duration: String)
}

struct FilterChipViewModel: Equatable {
    let filter: MediaFilter
    let count: Int

    /// A type with nothing in it today is dimmed and can't be picked. "All" is always available.
    var isEnabled: Bool { filter == .all || count > 0 }
}

struct SectionViewModel {
    let title: String
    let subtitle: String
    let itemIDs: [String]
    let badges: [ItemBadge]
}

struct MessageViewModel {
    let icon: String
    let text: String
    let actionTitle: String?
}

struct BannerViewModel {
    let text: String
    let actionTitle: String
}

// MARK: - View

protocol OnThisDayViewProtocol: BinnedNoticeShowing {
    func show(dateText: String)
    func show(quote: String)
    func show(stats: BoothStats)
    func show(twins: BannerViewModel?)
    func select(ids: Set<String>)
    func showCelebration(text: String)
    func show(isLoading: Bool)
    func show(days: [DayChipViewModel], selected: Int)
    func show(filters: [FilterChipViewModel], selected: MediaFilter)
    func show(sortAvailable: Bool)
    func show(sections: [SectionViewModel])
    func show(message: MessageViewModel?)
    func show(banner: BannerViewModel?)
    func setSelection(active: Bool, count: Int)
    func showError(title: String, message: String)
    func thumbnailView(for id: String) -> UIView?
}

// MARK: - Presenter

protocol OnThisDayPresenterProtocol: AnyObject {
    var isSelecting: Bool { get }
    func viewDidLoad()
    func viewWillEnterForeground()
    func didTapSelect()
    func didSelectDay(offset: Int)
    func didSelectFilter(_ filter: MediaFilter)
    func didTapSwipeSort()
    func didTapBinny()
    func didTapStats()
    func didTapTwins()
    func didTapPhoto(id: String)
    func didRequestKeep(id: String)
    func didRequestBin(id: String)
    func didSelect(id: String)
    func didDeselect(id: String)
    func didTapBin()
    func didTapMessageAction()
    func didTapBanner()
    func loadThumbnail(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?
    func cancelThumbnail(_ token: ThumbnailToken)
    func startCaching(ids: [String], targetSize: CGSize)
    func stopCaching(ids: [String], targetSize: CGSize)
}

// MARK: - Interactor

protocol OnThisDayInteractorProtocol: PhotoViewerInteractorProtocol {
    var access: PhotoAccess { get }
    func requestAccess() async -> PhotoAccess
    func loadSections(dayOffset: Int) async -> [MemorySection]
    func findTwins(in sections: [MemorySection]) async -> [[String]]
    func loadThumbnail(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?
    func cancelThumbnail(_ token: ThumbnailToken)
    func startCaching(ids: [String], targetSize: CGSize)
    func stopCaching(ids: [String], targetSize: CGSize)
}

// MARK: - Router

protocol OnThisDayRouterProtocol: AnyObject {
    func openSettings()
    func showLimitedOptions(onPickerFinished: @escaping () -> Void)
    func openViewer(items: [ViewerItem], startIndex: Int, interactor: PhotoViewerInteractorProtocol,
                    onChanged: @escaping () -> Void)
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void)
    func showYearPicker(dateText: String, options: [YearOption], onPick: @escaping (YearChoice) -> Void)
    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void)
    func openSwipeSort(items: [ViewerItem], interactor: PhotoViewerInteractorProtocol, onFinished: @escaping () -> Void)
    func openStats(stats: BoothStats, earnedStickers: Set<String>, reminderOn: Bool,
                   onToggleReminder: @escaping (Bool, @escaping (Bool) -> Void) -> Void,
                   onResetKept: @escaping () -> Void)
}
