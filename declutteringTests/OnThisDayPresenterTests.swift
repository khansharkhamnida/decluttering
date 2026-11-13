import Testing
import UIKit
@testable import decluttering

@MainActor
struct OnThisDayPresenterTests {

    let view = MockOnThisDayView()
    let interactor = MockInteractor()
    let router = MockRouter()
    let decisions = MockDecisions()
    let reminders = MockReminders()
    let breaks = BreakPolicy(defaults: UserDefaults(suiteName: "breaks-\(UUID().uuidString)")!)

    private func makePresenter() -> OnThisDayPresenter {
        OnThisDayPresenter(view: view, interactor: interactor, router: router, decisions: decisions, reminders: reminders, breaks: breaks)
    }

    private func loaded(_ presenter: OnThisDayPresenter) async {
        presenter.viewDidLoad()
        _ = await eventually { !view.sectionUpdates.isEmpty || !view.messages.compactMap { $0 }.isEmpty }
    }

    // MARK: Loading

    @Test func showsFoldersWithYearAndAgeSubtitle() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)

        let sections = view.sectionUpdates.last ?? []
        #expect(sections.map(\.title) == ["2025", "2024"])
        #expect(sections.map(\.subtitle) == ["1 year ago · 2 items", "2 years ago · 1 item"])
        #expect(sections.first?.itemIDs == ["a", "b"])
        #expect(view.quotes.count == 1)
    }

    @Test func deniedAccessOffersSettings() async {
        interactor.access = .denied
        let presenter = makePresenter()
        await loaded(presenter)

        #expect(view.messages.compactMap { $0 }.last?.actionTitle == "Open Settings")
        presenter.didTapMessageAction()
        #expect(router.settingsOpened == 1)
        #expect(view.sectionUpdates.allSatisfy { $0.isEmpty })
    }

    @Test func notDeterminedAsksForAccessFirst() async {
        interactor.access = .notDetermined
        interactor.grantedAfterRequest = .full
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        #expect(view.sectionUpdates.last?.count == 1)
    }

    @Test func limitedAccessShowsOptionsInsteadOfSettings() async {
        interactor.access = .limited
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        #expect(view.banners.compactMap { $0 }.last?.actionTitle == "Options")
        presenter.didTapBanner()
        #expect(router.limitedOptionsShown == 1)
        #expect(router.settingsOpened == 0)
    }

    @Test func emptyLimitedLibraryOffersToChooseMore() async {
        interactor.access = .limited
        let presenter = makePresenter()
        await loaded(presenter)

        #expect(view.messages.compactMap { $0 }.last?.actionTitle == "Choose more photos")
        presenter.didTapMessageAction()
        #expect(router.limitedOptionsShown == 1)
    }

    @Test func keptPhotosAreHidden() async {
        decisions.kept = ["b"]
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)

        let sections = view.sectionUpdates.last ?? []
        #expect(sections.first?.itemIDs == ["a"])
        #expect(sections.count == 2)
    }

    @Test func everythingKeptShowsAKeeperMessage() async {
        decisions.kept = ["a"]
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        #expect(view.messages.compactMap { $0 }.last?.text.contains("keeper") == true)
    }

    // MARK: Type filter

    private let mixed = [MemoryItem(id: "p1"), MemoryItem(id: "p2"),
                         MemoryItem(id: "v1", kind: .video, duration: 12),
                         MemoryItem(id: "s1", isScreenshot: true),
                         MemoryItem(id: "l1", kind: .livePhoto)]

    @Test func chipsListEachTypeWithItsCount() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)

        let chips = view.filterChips.last ?? []
        #expect(chips.map(\.filter) == [.all, .photos, .livePhotos, .videos, .screenshots])
        #expect(chips.map(\.count) == [5, 2, 1, 1, 1])
        #expect(view.filterSelections.last == .all)
    }

    @Test func everyDayShowsTheSameFiveChips() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        let chips = view.filterChips.last ?? []
        #expect(chips.map(\.filter) == MediaFilter.allCases)
        #expect(chips.map(\.count) == [2, 2, 0, 0, 0])
        #expect(chips.map(\.isEnabled) == [true, true, false, false, false])
    }

    @Test func aDayWithNoPhotosHasNothingToFilter() async {
        let presenter = makePresenter()
        await loaded(presenter)
        #expect(view.filterChips.last?.isEmpty == true)
    }

    @Test func aTypeWithNothingInItCannotBePicked() {
        #expect(FilterChipViewModel(filter: .videos, count: 0).isEnabled == false)
        #expect(FilterChipViewModel(filter: .videos, count: 2).isEnabled == true)
        #expect(FilterChipViewModel(filter: .all, count: 0).isEnabled == true)
    }

    @Test func pickingATypeShowsOnlyThatTypeInEveryYear() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed),
                               mediaSection(year: 2024, yearsAgo: 2, items: [MemoryItem(id: "v2", kind: .video, duration: 5), MemoryItem(id: "p3")])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didSelectFilter(.videos)
        let sections = view.sectionUpdates.last ?? []
        #expect(sections.map(\.title) == ["2025", "2024"])
        #expect(sections.map(\.itemIDs) == [["v1"], ["v2"]])
        #expect(view.filterSelections.last == .videos)
    }

    @Test func aTypeThatMatchesNothingInAYearLeavesThatFolderOut() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed),
                               mediaSection(year: 2024, yearsAgo: 2, items: [MemoryItem(id: "p3"), MemoryItem(id: "p4")])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didSelectFilter(.screenshots)
        #expect(view.sectionUpdates.last?.map(\.title) == ["2025"])
    }

    @Test func switchingTypeIsInstantAndLeavesSelectMode() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSelect()
        presenter.didSelect(id: "p1")

        presenter.didSelectFilter(.videos)
        #expect(presenter.isSelecting == false)
        #expect(view.selection.last?.active == false)
    }

    @Test func theTwinsBannerOnlyShowsWithNoFilter() async {
        interactor.twins = [["p1", "p2"]]
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)
        _ = await eventually { view.twinsBanners.contains { $0 != nil } }

        presenter.didSelectFilter(.videos)
        #expect(view.twinsBanners.last ?? nil == nil)

        presenter.didSelectFilter(.all)
        #expect(view.twinsBanners.last??.text.contains("1 look-alike photo") == true)
    }

    @Test func swipeSortFollowsTheActiveFilter() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didSelectFilter(.videos)
        presenter.didTapSwipeSort()
        #expect(router.swipeSortItems?.map(\.id) == ["v1"])
        #expect(router.swipeSortItems?.first?.kind == .video)
    }

    @Test func keepingTheLastOfATypeFallsBackToAll() async {
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didSelectFilter(.videos)

        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed.filter { $0.id != "v1" })]
        presenter.didRequestKeep(id: "v1")
        _ = await eventually { view.filterSelections.last == .all }

        #expect(view.filterSelections.last == .all)
        #expect(view.sectionUpdates.last?.first?.itemIDs.contains("v1") == false)
    }

    @Test func theSortButtonFollowsWhatIsOnScreen() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)
        #expect(view.sortAvailability.last == true)
    }

    // MARK: Opening photos

    @Test func tappingAPhotoOpensTheViewerOnThatPhoto() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapPhoto(id: "c")
        #expect(router.openedViewer?.items.map(\.id) == ["a", "b", "c"])
        #expect(router.openedViewer?.startIndex == 2)
        #expect(router.openedViewer?.items.last?.subtitle == "2 years ago")
    }

    // MARK: Binning

    @Test func binningAsksForConfirmationBeforeDeleting() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didSelect(id: "b")
        presenter.didTapBin()

        #expect(Set(router.confirmedIDs.first ?? []) == ["a", "b"])
        #expect(interactor.deletedIDs.isEmpty)
    }

    @Test func confirmedBinDeletesRecordsAndCelebrates() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.celebrations.isEmpty }

        #expect(interactor.deletedIDs == [["a"]])
        #expect(decisions.binned == ["a"])
        #expect(view.celebrations.first?.contains("1 photo") == true)
        #expect(presenter.isSelecting == false)
    }

    @Test func cancellingTheSystemPromptChangesNothing() async {
        interactor.deleteResult = .cancelled
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(decisions.binned.isEmpty)
        #expect(view.celebrations.isEmpty)
        #expect(presenter.isSelecting == true)
    }

    @Test func aFailedDeleteShowsAnError() async {
        interactor.deleteError = NSError(domain: "test", code: 1)
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !view.errors.isEmpty }

        #expect(view.errors.first == "Couldn't bin those")
        #expect(decisions.binned.isEmpty)
    }

    @Test func selectionCountFollowsSelectAndDeselect() async {
        let presenter = makePresenter()
        presenter.didTapSelect()
        presenter.didSelect(id: "a")
        presenter.didSelect(id: "b")
        presenter.didDeselect(id: "a")

        #expect(view.selection.last?.count == 1)
        presenter.didTapSelect()
        #expect(view.selection.last?.active == false)
    }

    // MARK: Quick actions and twins

    @Test func voiceOverKeepRecordsAndRefreshes() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didRequestKeep(id: "a")
        _ = await eventually { view.sectionUpdates.last?.first?.itemIDs == ["b"] }

        #expect(decisions.kept.contains("a"))
        #expect(view.celebrations.isEmpty == false)
    }

    @Test func voiceOverBinAsksForConfirmation() async {
        let presenter = makePresenter()
        presenter.didRequestBin(id: "a")
        #expect(router.confirmedIDs == [["a"]])
    }

    @Test func twinsBannerCountsTheExtrasAndReviewSelectsThem() async {
        interactor.twins = [["a", "b", "c"], ["d", "e"]]
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b", "c", "d", "e"])]
        let presenter = makePresenter()
        await loaded(presenter)
        _ = await eventually { view.twinsBanners.contains { $0 != nil } }

        #expect(view.twinsBanners.compactMap { $0 }.last?.text.contains("3 look-alike photos") == true)

        presenter.didTapTwins()
        #expect(view.selectedIDs == ["b", "c", "e"])
        #expect(presenter.isSelecting)
    }

    // MARK: Binny and the report

    @Test func tappingBinnyGivesADifferentQuote() async {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.didTapBinny()
        #expect(view.quotes.count == 2)
        #expect(view.quotes[0] != view.quotes[1])
    }

    @Test func swipeSortAsksWhichYearWhenThereAreSeveral() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSwipeSort()

        #expect(router.yearPickerOptions?.map(\.title) == ["2025", "2024"])
        #expect(router.yearPickerOptions?.map(\.count) == [2, 1])
        #expect(router.swipeSortItems == nil)
    }

    @Test func choosingAYearSortsOnlyThatYear() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSwipeSort()

        router.pickYear?(.year("2024"))
        #expect(router.swipeSortItems?.map(\.id) == ["c"])
        #expect(router.swipeSortItems?.first?.title == "2024")
    }

    @Test func choosingAllYearsSortsEverythingFromToday() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"]), section(year: 2024, yearsAgo: 2, ids: ["c"])]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSwipeSort()

        router.pickYear?(.all)
        #expect(router.swipeSortItems?.map(\.id) == ["a", "b", "c"])
    }

    @Test func aSingleYearSkipsThePicker() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSwipeSort()
        #expect(router.yearPickerOptions == nil)
        #expect(router.swipeSortItems?.map(\.id) == ["a", "b"])
    }

    @Test func keptPhotosNeverReachSwipeSort() async {
        decisions.kept = ["a"]
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didTapSwipeSort()
        #expect(router.swipeSortItems?.map(\.id) == ["b"])
    }

    @Test func swipeSortWithNothingFromTodayExplainsWhy() async {
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSwipeSort()

        #expect(router.swipeSortItems == nil)
        #expect(router.yearPickerOptions == nil)
        #expect(view.quotes.last?.contains("Nothing to sort") == true)
    }

    @Test func theSortButtonIsOnlyOfferedWithPhotoAccess() async {
        interactor.access = .denied
        let presenter = makePresenter()
        await loaded(presenter)
        #expect(view.sortAvailability.last == false)
    }

    @Test func reportShowsAndRemindersCanBeSwitchedOn() async {
        let presenter = makePresenter()
        presenter.didTapStats()
        _ = await eventually { router.statsShown }

        var result: Bool?
        router.reminderToggle?(true) { result = $0 }
        _ = await eventually { result != nil }
        #expect(result == true)
        #expect(reminders.enabled)

        router.reminderToggle?(false) { result = $0 }
        #expect(reminders.enabled == false)
    }

    @Test func refusedNotificationPermissionReportsFailure() async {
        reminders.allowEnable = false
        let presenter = makePresenter()
        presenter.didTapStats()
        _ = await eventually { router.statsShown }

        var result: Bool?
        router.reminderToggle?(true) { result = $0 }
        _ = await eventually { result != nil }
        #expect(result == false)
    }

    @Test func bringingKeptPhotosBackClearsTheKeptList() async {
        decisions.kept = ["a"]
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapStats()
        _ = await eventually { router.statsShown }

        router.resetKept?()
        #expect(decisions.kept.isEmpty)
        _ = await eventually { view.sectionUpdates.last?.first?.itemIDs == ["a"] }
    }

    // MARK: Days around today

    @Test func sevenDayChipsCenterOnToday() async {
        let presenter = makePresenter()
        await loaded(presenter)

        let chips = view.dayChips.last ?? []
        #expect(chips.map(\.offset) == [-3, -2, -1, 0, 1, 2, 3])
        #expect(chips.filter(\.isToday).map(\.offset) == [0])
        #expect(chips[3].label.hasPrefix("Today"))
        #expect(view.daySelections.last == 0)
    }

    @Test func pickingADayLoadsThatDay() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didSelectDay(offset: -2)
        _ = await eventually { interactor.loadedOffsets.contains(-2) }

        #expect(interactor.loadedOffsets.last == -2)
        #expect(view.daySelections.last == -2)
    }

    @Test func pickingADayLeavesSelectModeAndShowsNothingUntilLoaded() async {
        let mixed = [MemoryItem(id: "p1"), MemoryItem(id: "v1", kind: .video, duration: 9)]
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSelect()
        presenter.didSelect(id: "v1")

        presenter.didSelectDay(offset: 1)
        #expect(presenter.isSelecting == false)
        #expect(view.sectionUpdates.last?.isEmpty == true)
    }

    @Test func oneTypeFilterAppliesToEveryDay() async {
        let mixed = [MemoryItem(id: "p1"), MemoryItem(id: "v1", kind: .video, duration: 9)]
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: mixed)]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didSelectFilter(.videos)

        presenter.didSelectDay(offset: 1)
        _ = await eventually { view.sectionUpdates.last?.first?.itemIDs == ["v1"] }

        #expect(view.filterSelections.last == .videos)
        #expect(view.sectionUpdates.last?.first?.itemIDs == ["v1"])
    }

    @Test func aTypeMissingOnOneDayShowsEverythingThenComesBack() async {
        let withVideo = [MemoryItem(id: "p1"), MemoryItem(id: "v1", kind: .video, duration: 9)]
        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: withVideo)]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didSelectFilter(.videos)

        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        presenter.didSelectDay(offset: 1)
        _ = await eventually { view.sectionUpdates.last?.first?.itemIDs == ["a", "b"] }
        #expect(view.filterSelections.last == .all)

        interactor.sections = [mediaSection(year: 2025, yearsAgo: 1, items: withVideo)]
        presenter.didSelectDay(offset: 2)
        _ = await eventually { view.sectionUpdates.last?.first?.itemIDs == ["v1"] }
        #expect(view.filterSelections.last == .videos)
    }

    @Test func daysOutsideTheWindowAreIgnored() async {
        let presenter = makePresenter()
        await loaded(presenter)
        let loads = interactor.loadedOffsets.count

        presenter.didSelectDay(offset: 4)
        presenter.didSelectDay(offset: -9)
        presenter.didSelectDay(offset: 0)
        #expect(interactor.loadedOffsets.count == loads)
    }

    @Test func thisYearsPhotosFromAnotherDayAreNotCalledToday() async {
        interactor.sections = [section(year: 2026, yearsAgo: 0, ids: ["a"]), section(year: 2025, yearsAgo: 1, ids: ["b"])]
        let presenter = makePresenter()
        await loaded(presenter)
        #expect(view.sectionUpdates.last?.first?.subtitle == "Today · 1 item")

        presenter.didSelectDay(offset: -1)
        _ = await eventually { view.sectionUpdates.last?.first?.subtitle.hasPrefix("This year") == true }
        #expect(view.sectionUpdates.last?.first?.subtitle == "This year · 1 item")
    }

    @Test func theYearPickerNamesTheChosenDay() async {
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"]), section(year: 2024, yearsAgo: 2, ids: ["b"])]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didTapSwipeSort()
        #expect(router.yearPickerDate?.isEmpty == false)
    }

    // MARK: Break reminders

    private func bin(_ presenter: OnThisDayPresenter, ids: [String]) async {
        presenter.didTapSelect()
        ids.forEach { presenter.didSelect(id: $0) }
        presenter.didTapBin()
        router.pendingConfirm?()
        _ = await eventually { !interactor.deletedIDs.isEmpty }
    }

    @Test func crossingFortyPhotosSuggestsAGentleBreak() async {
        decisions.earlierToday = BreakPolicy.gentleAt - 2
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b", "c"])]
        let presenter = makePresenter()
        await loaded(presenter)

        await bin(presenter, ids: ["a", "b", "c"])
        _ = await eventually(timeout: 5) { !router.breakReminders.isEmpty }

        #expect(router.breakReminders.first?.level == .gentle)
        #expect(router.breakReminders.first?.count == BreakPolicy.gentleAt + 1)
    }

    @Test func staysQuietBelowTheLimit() async {
        decisions.earlierToday = 0
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        await bin(presenter, ids: ["a"])
        try? await Task.sleep(for: .seconds(1.8))
        #expect(router.breakReminders.isEmpty)
    }

    @Test func eachLevelIsOnlyShownOncePerDay() async {
        decisions.earlierToday = BreakPolicy.gentleAt + 1
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a", "b"])]
        let presenter = makePresenter()
        await loaded(presenter)

        await bin(presenter, ids: ["a"])
        _ = await eventually(timeout: 5) { !router.breakReminders.isEmpty }
        let shown = router.breakReminders.count

        presenter.didRequestKeep(id: "b")
        try? await Task.sleep(for: .seconds(1.8))
        #expect(router.breakReminders.count == shown)
    }

    @Test func aHugeDayGoesStraightToTheRestMessage() async {
        decisions.earlierToday = BreakPolicy.restAt - 1
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)

        presenter.didRequestKeep(id: "a")
        _ = await eventually(timeout: 5) { !router.breakReminders.isEmpty }
        #expect(router.breakReminders.map(\.level) == [.rest])
    }

    @Test func takingTheBreakGivesARestLine() async {
        decisions.earlierToday = BreakPolicy.gentleAt
        interactor.sections = [section(year: 2025, yearsAgo: 1, ids: ["a"])]
        let presenter = makePresenter()
        await loaded(presenter)
        presenter.didRequestKeep(id: "a")
        _ = await eventually(timeout: 5) { router.breakAction != nil }

        router.breakAction?()
        #expect(BoothVoice.restLines.contains(view.quotes.last ?? ""))
    }

    @Test func openingTheBoothAfterABigDayShowsARestLine() async {
        decisions.earlierToday = BreakPolicy.restAt + 20
        let presenter = makePresenter()
        presenter.viewDidLoad()
        #expect(BoothVoice.restLines.contains(view.quotes.first ?? ""))
    }

    @Test func aNormalDayStillStartsWithAQuote() async {
        decisions.earlierToday = 0
        let presenter = makePresenter()
        presenter.viewDidLoad()
        #expect(BoothVoice.quotes.contains(view.quotes.first ?? ""))
    }
}
