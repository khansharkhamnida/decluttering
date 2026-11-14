import AVFoundation
import Photos
import UIKit
@testable import decluttering

// MARK: - Helpers

/// Presenters start Tasks internally, so tests wait for the outcome instead of sleeping a fixed time.
@MainActor
func eventually(timeout: TimeInterval = 4, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

func mediaSection(year: Int, yearsAgo: Int, items: [MemoryItem]) -> MemorySection {
    MemorySection(date: Calendar.current.date(from: DateComponents(year: year, month: 11, day: 13)) ?? .now,
                  yearsAgo: yearsAgo, items: items)
}

func section(year: Int, yearsAgo: Int, ids: [String], label: String? = nil) -> MemorySection {
    MemorySection(date: Calendar.current.date(from: DateComponents(year: year, month: 11, day: 13)) ?? .now,
                  yearsAgo: yearsAgo, items: ids.map { MemoryItem(id: $0) }, label: label)
}

// MARK: - Main screen mocks

@MainActor
final class MockOnThisDayView: OnThisDayViewProtocol {
    var dateTexts: [String] = []
    var quotes: [String] = []
    var stats: [BoothStats] = []
    var twinsBanners: [BannerViewModel?] = []
    var selectedIDs: Set<String> = []
    var celebrations: [String] = []
    var binnedCounts: [Int] = []
    var loading: [Bool] = []
    var dayChips: [[DayChipViewModel]] = []
    var daySelections: [Int] = []
    var filterChips: [[FilterChipViewModel]] = []
    var filterSelections: [MediaFilter] = []
    var sectionUpdates: [[SectionViewModel]] = []
    var messages: [MessageViewModel?] = []
    var banners: [BannerViewModel?] = []
    var selection: [(active: Bool, count: Int)] = []
    var errors: [String] = []
    var sortAvailability: [Bool] = []

    func show(dateText: String) { dateTexts.append(dateText) }
    func show(quote: String) { quotes.append(quote) }
    func show(stats: BoothStats) { self.stats.append(stats) }
    func show(twins: BannerViewModel?) { twinsBanners.append(twins) }
    func select(ids: Set<String>) { selectedIDs = ids }
    func showCelebration(text: String) { celebrations.append(text) }
    func showBinned(count: Int) { binnedCounts.append(count) }
    func show(isLoading: Bool) { loading.append(isLoading) }
    func show(days: [DayChipViewModel], selected: Int) { dayChips.append(days); daySelections.append(selected) }
    func show(filters: [FilterChipViewModel], selected: MediaFilter) { filterChips.append(filters); filterSelections.append(selected) }
    func show(sortAvailable: Bool) { sortAvailability.append(sortAvailable) }
    func show(sections: [SectionViewModel]) { sectionUpdates.append(sections) }
    func show(message: MessageViewModel?) { messages.append(message) }
    func show(banner: BannerViewModel?) { banners.append(banner) }
    func setSelection(active: Bool, count: Int) { selection.append((active, count)) }
    func showError(title: String, message: String) { errors.append(title) }
    func thumbnailView(for id: String) -> UIView? { nil }
}

@MainActor
final class MockInteractor: @MainActor OnThisDayInteractorProtocol {
    var access: PhotoAccess = .full
    var grantedAfterRequest: PhotoAccess = .full
    var sections: [MemorySection] = []
    private(set) var loadedOffsets: [Int] = []
    var twins: [[String]] = []
    var deleteResult: DeleteResult = .deleted
    var deleteError: Error?
    private(set) var deletedIDs: [[String]] = []

    func requestAccess() async -> PhotoAccess { access = grantedAfterRequest; return grantedAfterRequest }
    func loadSections(dayOffset: Int) async -> [MemorySection] { loadedOffsets.append(dayOffset); return sections }
    func findTwins(in sections: [MemorySection]) async -> [[String]] { twins }
    func loadThumbnail(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? { nil }
    func cancelThumbnail(_ token: ThumbnailToken) {}
    func startCaching(ids: [String], targetSize: CGSize) {}
    func stopCaching(ids: [String], targetSize: CGSize) {}
    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? { nil }
    func cancelImage(_ token: ThumbnailToken) {}
    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken? { nil }
    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken? { nil }

    func delete(ids: [String]) async throws -> DeleteResult {
        deletedIDs.append(ids)
        if let deleteError { throw deleteError }
        return deleteResult
    }
}

@MainActor
final class MockRouter: OnThisDayRouterProtocol {
    var settingsOpened = 0
    var limitedOptionsShown = 0
    var openedViewer: (items: [ViewerItem], startIndex: Int)?
    var viewerOnChanged: (() -> Void)?
    var confirmedIDs: [[String]] = []
    var pendingConfirm: (() -> Void)?
    var yearPickerOptions: [YearOption]?
    var yearPickerDate: String?
    var breakReminders: [(level: BreakLevel, count: Int)] = []
    var breakAction: (() -> Void)?
    var pickYear: ((YearChoice) -> Void)?
    var swipeSortItems: [ViewerItem]?
    var swipeSortOnFinished: (() -> Void)?
    var statsShown = false
    var reminderToggle: ((Bool, @escaping (Bool) -> Void) -> Void)?
    var resetKept: (() -> Void)?

    func openSettings() { settingsOpened += 1 }
    func showLimitedOptions(onPickerFinished: @escaping () -> Void) { limitedOptionsShown += 1 }
    func openViewer(items: [ViewerItem], startIndex: Int, interactor: PhotoViewerInteractorProtocol, onChanged: @escaping () -> Void) {
        openedViewer = (items, startIndex); viewerOnChanged = onChanged
    }
    func confirmBin(ids: [String], onConfirm: @escaping () -> Void) { confirmedIDs.append(ids); pendingConfirm = onConfirm }
    func showYearPicker(dateText: String, options: [YearOption], onPick: @escaping (YearChoice) -> Void) {
        yearPickerDate = dateText; yearPickerOptions = options; pickYear = onPick
    }
    func showBreakReminder(level: BreakLevel, count: Int, onBreak: @escaping () -> Void) {
        breakReminders.append((level, count)); breakAction = onBreak
    }
    func openSwipeSort(items: [ViewerItem], interactor: PhotoViewerInteractorProtocol, onFinished: @escaping () -> Void) {
        swipeSortItems = items; swipeSortOnFinished = onFinished
    }
    func openStats(stats: BoothStats, earnedStickers: Set<String>, reminderOn: Bool,
                   onToggleReminder: @escaping (Bool, @escaping (Bool) -> Void) -> Void, onResetKept: @escaping () -> Void) {
        statsShown = true; reminderToggle = onToggleReminder; resetKept = onResetKept
    }
}

@MainActor
final class MockDecisions: DecisionRecording {
    var kept: Set<String> = []
    private(set) var binned: [String] = []
    private(set) var keptLog: [String] = []
    var earlierToday = 0
    var currentStats = BoothStats(binned: 0, kept: 0, streak: 0)

    func todayCount() -> Int { earlierToday + binned.count + keptLog.count }
    func recordKept(ids: [String]) { kept.formUnion(ids); keptLog += ids }
    func recordBinned(ids: [String]) { binned += ids }
    func removeKept(ids: [String]) { kept.subtract(ids) }
    func keptIDs() -> Set<String> { kept }
    func stats() -> BoothStats { currentStats }
    func resetKept() { kept = [] }
}

@MainActor
final class MockReminders: ReminderScheduling {
    var enabled = false
    var allowEnable = true
    func isEnabled() async -> Bool { enabled }
    func enable() async -> Bool { enabled = allowEnable; return allowEnable }
    func disable() { enabled = false }
}
