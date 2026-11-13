import UIKit

final class OnThisDayPresenter: OnThisDayPresenterProtocol {

    private weak var view: OnThisDayViewProtocol?
    private let interactor: OnThisDayInteractorProtocol
    private let router: OnThisDayRouterProtocol
    private let decisions: DecisionRecording
    private let reminders: ReminderScheduling
    private let breaks: BreakPolicy

    private(set) var isSelecting = false
    private var selectedIDs = Set<String>()
    private var shownIDs: [[String]]?
    private var loadGeneration = 0
    private var loadedSections: [MemorySection] = []
    private var quote = BoothVoice.quoteOfTheDay()
    /// The type the person picked. It stays across days, even on a day with none of that type.
    private var filter: MediaFilter = .all
    /// What is actually showing right now: the picked type, or everything if this day has none of it.
    private var activeFilter: MediaFilter = .all
    private var dayOffset = 0
    private static let dayRange = -3...3
    private var unfilteredSections: [MemorySection] = []
    private var hadAnyPhotos = false
    private var access: PhotoAccess = .notDetermined
    private var twinGroups: [[String]] = []
    private var twinsComputedFor: [[String]]?

    init(view: OnThisDayViewProtocol, interactor: OnThisDayInteractorProtocol, router: OnThisDayRouterProtocol,
         decisions: DecisionRecording, reminders: ReminderScheduling, breaks: BreakPolicy) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.decisions = decisions
        self.reminders = reminders
        self.breaks = breaks
    }

    // MARK: Lifecycle

    func viewDidLoad() {
        // After a very big day, Binny greets people with a rest line instead of a quote
        if BreakPolicy.level(forCount: decisions.todayCount()) == .rest { quote = BoothVoice.restLine() }
        showHeader()
        view?.show(quote: quote)
        refresh()
    }

    func viewWillEnterForeground() {
        showHeader()
        refresh()
    }

    private func showHeader() {
        view?.show(dateText: targetDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        view?.show(days: dayChips(), selected: dayOffset)
        updateStats()
    }

    private var targetDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
    }

    private func dayChips() -> [DayChipViewModel] {
        Self.dayRange.map { offset in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
            let spoken = date.formatted(.dateTime.weekday(.wide).month(.wide).day()) + (offset == 0 ? ", today" : "")
            let label = offset == 0
                ? "Today · " + date.formatted(.dateTime.day().month(.abbreviated))
                : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return DayChipViewModel(offset: offset, label: label, isToday: offset == 0, spoken: spoken)
        }
    }

    /// Another day is a different set of photos, so it loads again.
    func didSelectDay(offset: Int) {
        guard offset != dayOffset, Self.dayRange.contains(offset) else { return }
        dayOffset = offset
        isSelecting = false
        selectedIDs.removeAll()
        shownIDs = nil
        loadedSections = []
        unfilteredSections = []
        twinGroups = []
        twinsComputedFor = nil
        view?.setSelection(active: false, count: 0)
        view?.show(twins: nil)
        view?.show(sections: [])
        view?.show(sortAvailable: false)
        showHeader()
        refresh(force: true)
    }

    // MARK: Break reminders

    /// Looks at how much was sorted today and suggests a rest at 40 and again at 100, once each.
    /// The short wait lets the bin or keep celebration finish first.
    private func checkBreak(after delay: Double = 1.4) {
        let count = decisions.todayCount()
        guard let level = breaks.nudge(forCount: count) else { return }
        Task {
            try? await Task.sleep(for: .seconds(delay))
            router.showBreakReminder(level: level, count: count) { [weak self] in
                self?.view?.show(quote: BoothVoice.restLine())
            }
        }
    }

    /// Refreshes Binny's stats line and announces any sticker that was just earned.
    private func updateStats(afterAction: Bool = false) {
        let stats = decisions.stats()
        view?.show(stats: stats)
        let earned = StickerBook.newlyEarned(for: stats)
        guard let first = earned.first else { return }
        let text = earned.count == 1 ? "New sticker: \(first.name)!" : "\(earned.count) new stickers! Peek in your Booth Report."
        Task {
            // After an action the bin or keep message is still on screen, so wait for it to finish
            try? await Task.sleep(for: .seconds(afterAction ? 3.2 : 0.8))
            view?.showCelebration(text: text)
        }
    }

    /// Switching type only re-sorts what is already loaded, so it is instant and never fetches again.
    func didSelectFilter(_ newFilter: MediaFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        isSelecting = false
        selectedIDs.removeAll()
        view?.setSelection(active: false, count: 0)
        showCurrent(force: true, generation: loadGeneration)
    }

    // MARK: Actions

    /// Outside select mode a tap opens the photo full screen, with every photo of the day to swipe through.
    func didTapPhoto(id: String) {
        let items = viewerItems()
        guard let startIndex = items.firstIndex(where: { $0.id == id }) else { return }
        router.openViewer(items: items, startIndex: startIndex, interactor: interactor) { [weak self] in
            self?.updateStats(afterAction: true)
            self?.refresh(force: true)
            self?.checkBreak()
        }
    }

    /// VoiceOver actions on a single photo, so nobody has to enter select mode to keep or bin one.
    func didRequestKeep(id: String) {
        decisions.recordKept(ids: [id])
        BoothHaptics.shared.sparkle()
        view?.showCelebration(text: BoothVoice.keepLine())
        updateStats(afterAction: true)
        refresh(force: true)
        checkBreak()
    }

    func didRequestBin(id: String) {
        router.confirmBin(ids: [id]) { [weak self] in self?.performBin([id]) }
    }

    /// Swipe sort goes through what is on screen (so the type filter applies). With several years to choose from, it asks which one first.
    func didTapSwipeSort() {
        guard !loadedSections.isEmpty else {
            view?.show(quote: "Nothing to sort from this day yet. Come back tomorrow!")
            return
        }
        guard loadedSections.count > 1 else { return openSwipeSort(with: viewerItems()) }

        let options = loadedSections.map { section -> YearOption in
            let model = makeViewModel(section)
            return YearOption(key: model.title, title: model.title, subtitle: model.subtitle, count: section.items.count)
        }
        let dateText = targetDate.formatted(.dateTime.day().month(.wide))
        router.showYearPicker(dateText: dateText, options: options) { [weak self] choice in
            switch choice {
            case .all: self?.openSwipeSort(with: self?.viewerItems() ?? [])
            case .year(let key): self?.openSwipeSort(with: self?.viewerItems(onlyYear: key) ?? [])
            }
        }
    }

    private func openSwipeSort(with items: [ViewerItem]) {
        guard !items.isEmpty else {
            view?.show(quote: "Nothing to sort here yet. Come back tomorrow!")
            return
        }
        router.openSwipeSort(items: items, interactor: interactor) { [weak self] in
            self?.updateStats(afterAction: true)
            self?.refresh(force: true)
            self?.checkBreak()
        }
    }

    private func viewerItems(onlyYear year: String? = nil) -> [ViewerItem] {
        var items: [ViewerItem] = []
        for section in loadedSections {
            let model = makeViewModel(section)
            if let year, model.title != year { continue }
            for item in section.items {
                items.append(ViewerItem(id: item.id, title: model.title,
                                        subtitle: whenText(yearsAgo: section.yearsAgo),
                                        kind: item.kind))
            }
        }
        return items
    }

    func didTapSelect() {
        isSelecting.toggle()
        selectedIDs.removeAll()
        view?.setSelection(active: isSelecting, count: 0)
    }

    func didSelect(id: String) {
        selectedIDs.insert(id)
        view?.setSelection(active: true, count: selectedIDs.count)
    }

    func didDeselect(id: String) {
        selectedIDs.remove(id)
        view?.setSelection(active: true, count: selectedIDs.count)
    }

    func didTapBinny() {
        quote = BoothVoice.randomQuote(excluding: quote)
        view?.show(quote: quote)
    }

    func didTapStats() {
        Task {
            let reminderOn = await reminders.isEnabled()
            let stats = decisions.stats()
            router.openStats(
                stats: stats,
                earnedStickers: StickerBook.earnedIDs(for: stats),
                reminderOn: reminderOn,
                onToggleReminder: { [weak self] wanted, done in
                    guard let self else { return done(false) }
                    guard wanted else { self.reminders.disable(); return done(true) }
                    Task { done(await self.reminders.enable()) }
                },
                onResetKept: { [weak self] in
                    self?.decisions.resetKept()
                    self?.refresh(force: true)
                    self?.updateStats()
                })
        }
    }

    /// Pre-selects the extra copies of every look-alike group (the earliest photo in each group stays unticked).
    func didTapTwins() {
        let extras = Set(twinGroups.flatMap { $0.dropFirst() })
        guard !extras.isEmpty else { return }
        isSelecting = true
        selectedIDs = extras
        view?.select(ids: extras)
        view?.show(quote: "Twins ticked! Un-tick any keepers, then bin the extras.")
    }

    func didTapBin() {
        let ids = Array(selectedIDs)
        guard !ids.isEmpty else { return }
        router.confirmBin(ids: ids) { [weak self] in self?.performBin(ids) }
    }

    private func performBin(_ ids: [String]) {
        Task {
            do {
                guard try await interactor.delete(ids: ids) == .deleted else { return }
                decisions.recordBinned(ids: ids)
                isSelecting = false
                selectedIDs.removeAll()
                view?.setSelection(active: false, count: 0)
                view?.showCelebration(text: BoothVoice.celebration(count: ids.count))
                updateStats(afterAction: true)
                refresh(force: true)
                checkBreak()
            } catch {
                view?.showError(title: "Couldn't bin those", message: error.localizedDescription)
            }
        }
    }

    func didTapMessageAction() { openAccessOptions() }
    func didTapBanner() { openAccessOptions() }

    /// With limited access, people can add more photos right here instead of going to Settings.
    private func openAccessOptions() {
        guard access == .limited else { return router.openSettings() }
        router.showLimitedOptions { [weak self] in self?.refresh(force: true) }
    }

    func loadThumbnail(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? {
        interactor.loadThumbnail(id: id, targetSize: targetSize, completion: completion)
    }

    func cancelThumbnail(_ token: ThumbnailToken) { interactor.cancelThumbnail(token) }
    func startCaching(ids: [String], targetSize: CGSize) { interactor.startCaching(ids: ids, targetSize: targetSize) }
    func stopCaching(ids: [String], targetSize: CGSize) { interactor.stopCaching(ids: ids, targetSize: targetSize) }

    // MARK: Rendering

    /// Re-checks access and content. iOS shows the system permission prompt only once,
    /// so after that the user is sent to Settings instead.
    private func refresh(force: Bool = false) {
        loadGeneration += 1
        let generation = loadGeneration
        Task {
            var access = interactor.access
            if access == .notDetermined { access = await interactor.requestAccess() }
            await render(access, force: force, generation: generation)
        }
    }

    private func render(_ access: PhotoAccess, force: Bool, generation: Int) async {
        self.access = access
        switch access {
        case .notDetermined, .denied:
            shownIDs = nil
            view?.show(sortAvailable: false)
            view?.show(isLoading: false)
            view?.show(sections: [])
            view?.show(banner: nil)
            view?.show(message: MessageViewModel(
                icon: "lock.fill",
                text: "The booth needs your photos to find today's memories.\n\nTurn on Full Access in Settings for the best experience.",
                actionTitle: "Open Settings"))

        case .limited, .full:
            // Only the very first load shows a spinner; later refreshes update quietly
            if shownIDs == nil {
                view?.show(message: nil)
                view?.show(isLoading: true)
            }
            let everything = await interactor.loadSections(dayOffset: dayOffset)
            guard generation == loadGeneration else { return } // a newer refresh is already running

            // Photos you've already kept stay out of the booth
            let kept = decisions.keptIDs()
            hadAnyPhotos = !everything.isEmpty
            unfilteredSections = everything.compactMap { section in
                let items = section.items.filter { !kept.contains($0.id) }
                return items.isEmpty ? nil : MemorySection(date: section.date, yearsAgo: section.yearsAgo, items: items, label: section.label)
            }
            view?.show(isLoading: false)
            showCurrent(force: force, generation: generation)
        }
    }

    /// Applies the type filter to what was loaded and shows the result.
    private func showCurrent(force: Bool, generation: Int) {
        let allItems = unfilteredSections.flatMap(\.items)
        let counts = Dictionary(grouping: allItems, by: \.mediaFilter).mapValues(\.count)

        // Every day shows the same chips, so the row never jumps around. One filter applies to every day:
        // if the chosen type has nothing on this day, everything shows for now, and the choice is
        // remembered for the next day that has some.
        let hasPhotos = !allItems.isEmpty
        let active: MediaFilter = hasPhotos && (filter == .all || (counts[filter] ?? 0) > 0) ? filter : .all
        activeFilter = active
        view?.show(filters: hasPhotos
                   ? MediaFilter.allCases.map { FilterChipViewModel(filter: $0, count: $0 == .all ? allItems.count : counts[$0] ?? 0) }
                   : [],
                   selected: active)

        let sections: [MemorySection] = unfilteredSections.compactMap { section in
            let items = section.items.filter { active.matches($0) }
            return items.isEmpty ? nil : MemorySection(date: section.date, yearsAgo: section.yearsAgo, items: items, label: section.label)
        }
        loadedSections = sections
        view?.show(sortAvailable: !sections.isEmpty)

        view?.show(banner: access == .limited
            ? BannerViewModel(text: "Binny only sees some of your photos. Add more, or allow Full Access.",
                              actionTitle: "Options")
            : nil)

        if sections.isEmpty {
            view?.show(message: MessageViewModel(
                icon: "sparkles",
                text: access == .limited
                    ? "No memories in the photos you've shared.\n\nAdd more photos, or allow Full Access to include your whole library."
                    : (hadAnyPhotos ? "Everything left here is a keeper.\nCome back tomorrow!" : "Nothing to bin from this day.\nSnap. Sort. Bin."),
                actionTitle: access == .limited ? "Choose more photos" : nil))
        } else {
            view?.show(message: nil)
        }

        // Skip reloading when nothing changed, so a selection survives returning to the app
        let ids = sections.map { $0.items.map(\.id) }
        guard force || ids != shownIDs else { return }
        shownIDs = ids
        view?.show(sections: sections.map(makeViewModel))

        // Look-alikes are found across everything, so the banner only makes sense with no filter on
        if active == .all {
            findTwins(in: sections, generation: generation)
        } else {
            view?.show(twins: nil)
        }
    }

    private func findTwins(in sections: [MemorySection], generation: Int) {
        let ids = sections.map { $0.items.map(\.id) }
        if ids == twinsComputedFor { return showTwinsBanner() }
        twinGroups = []
        view?.show(twins: nil)
        Task {
            let groups = await interactor.findTwins(in: sections)
            guard generation == loadGeneration, activeFilter == .all else { return }
            twinsComputedFor = ids
            twinGroups = groups
            showTwinsBanner()
        }
    }

    private func showTwinsBanner() {
        let extras = twinGroups.reduce(0) { $0 + $1.count - 1 }
        view?.show(twins: extras == 0 ? nil : BannerViewModel(
            text: "Binny spotted \(extras) look-alike \(extras == 1 ? "photo" : "photos"). Review the extras?",
            actionTitle: "Review"))
    }

    private func makeViewModel(_ section: MemorySection) -> SectionViewModel {
        let count = section.items.count
        return SectionViewModel(title: section.date.formatted(.dateTime.year()),
                                subtitle: "\(whenText(yearsAgo: section.yearsAgo)) · \(count) item\(count == 1 ? "" : "s")",
                                itemIDs: section.items.map(\.id), badges: section.items.map(badge(for:)))
    }

    private func badge(for item: MemoryItem) -> ItemBadge {
        switch item.kind {
        case .photo: return .none
        case .livePhoto: return .live
        case .video:
            let seconds = Int(item.duration.rounded())
            return .video(duration: String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
    }

    private func whenText(yearsAgo: Int) -> String {
        if yearsAgo == 0 { return dayOffset == 0 ? "Today" : "This year" }
        return yearsAgo == 1 ? "1 year ago" : "\(yearsAgo) years ago"
    }
}
