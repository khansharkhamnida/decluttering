import UIKit

final class OnThisDayViewController: UIViewController {

    private enum Metrics {
        static let margin: CGFloat = 14   // curtain to folder
        static let padding: CGFloat = 8   // folder edge to photos
        static let spacing: CGFloat = 5   // between photos
    }

    var presenter: OnThisDayPresenterProtocol!

    private var sections: [SectionViewModel] = []
    private var collapsedTitles = Set<String>()
    private var poppedIDs = Set<String>()
    private var dragSelect: DragSelectController?

    private let marquee = MarqueeView()
    private let binnyCard = BinnyCardView()
    private let dayBar = DayBarView()
    private let filterBar = MediaFilterBar()
    private let banner = BannerView()
    private let twinsBanner = BannerView()
    private let messageView = MessageView()
    private let loadingView = LoadingView()
    private let feedback = UISelectionFeedbackGenerator()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseID)
        cv.register(SectionHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: SectionHeaderView.reuseID)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.prefetchDataSource = self
        cv.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 100, right: 0)
        return cv
    }()

    private lazy var statsButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "chart.bar.fill"), style: .plain, target: self, action: #selector(statsTapped))
        item.accessibilityLabel = "Booth Report"
        return item
    }()

    private lazy var selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(selectTapped))

    private lazy var paletteButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "paintpalette.fill"), style: .plain, target: self, action: #selector(themesTapped))
        item.accessibilityLabel = "Change look"
        return item
    }()

    private lazy var binButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "trash.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = BoothTheme.ink
        config.baseForegroundColor = BoothTheme.paper
        config.background.strokeColor = BoothTheme.onBackground
        config.background.strokeWidth = 3
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 26, bottom: 14, trailing: 26)
        let button = UIButton(configuration: config)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 5)
        button.addAction(UIAction { [weak self] _ in self?.presenter.didTapBin() }, for: .touchUpInside)
        button.alpha = 0
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Swipe sort sits at the bottom, where "Bin it" appears while selecting, so it reads as the main action
    /// and never as one of the filter chips.
    private lazy var sortButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "rectangle.stack.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = BoothTheme.primary
        config.baseForegroundColor = BoothTheme.onPrimary
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 26, bottom: 14, trailing: 26)
        config.attributedTitle = AttributedString("Swipe sort", attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        let button = UIButton(configuration: config)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 5)
        button.accessibilityLabel = "Swipe sort"
        button.accessibilityHint = "Sort the photos on screen one at a time"
        button.addAction(UIAction { [weak self] _ in self?.presenter.didTapSwipeSort() }, for: .touchUpInside)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var sortAvailable = false

    private func updateSortButton() {
        sortButton.isHidden = !(sortAvailable && !presenter.isSelecting)
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "On This Day"
        overrideUserInterfaceStyle = BoothTheme.interfaceStyle
        view.backgroundColor = BoothTheme.background
        navigationItem.rightBarButtonItems = [selectButton, paletteButton]
        navigationItem.leftBarButtonItem = statsButton
        navigationItem.largeTitleDisplayMode = .always
        setUpNavigationBar()
        setUpLayout()
        setUpDragSelect()

        banner.onTap = { [weak self] in self?.presenter.didTapBanner() }
        twinsBanner.onTap = { [weak self] in self?.presenter.didTapTwins() }
        binnyCard.onTap = { [weak self] in self?.presenter.didTapBinny() }
        dayBar.onSelect = { [weak self] offset in self?.presenter.didSelectDay(offset: offset) }
        filterBar.onSelect = { [weak self] filter in self?.presenter.didSelectFilter(filter) }
        filterBar.isHidden = true
        dayBar.onFoldTap = { [weak self] in
            guard let self else { return }
            setAllFolders(collapsed: !allFoldersCollapsed)
        }
        twinsBanner.isHidden = true
        messageView.onAction = { [weak self] in self?.presenter.didTapMessageAction() }
        banner.isHidden = true
        messageView.isHidden = true
        selectButton.isEnabled = false

        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        presenter.viewDidLoad()
    }

    private func setUpDragSelect() {
        dragSelect = DragSelectController(
            collectionView: collectionView,
            isSelecting: { [weak self] in self?.presenter.isSelecting ?? false },
            isSelected: { [weak self] path in self?.collectionView.indexPathsForSelectedItems?.contains(path) ?? false },
            beginSelecting: { [weak self] in self?.presenter.didTapSelect() },
            apply: { [weak self] path, select in
                guard let self, let id = self.itemID(at: path) else { return }
                if select {
                    self.collectionView.selectItem(at: path, animated: false, scrollPosition: [])
                    self.presenter.didSelect(id: id)
                } else {
                    self.collectionView.deselectItem(at: path, animated: false)
                    self.presenter.didDeselect(id: id)
                }
            })
    }

    @objc private func appWillEnterForeground() { presenter.viewWillEnterForeground() }

    // MARK: Setup

    private func setUpNavigationBar() {
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithOpaqueBackground()
        scrolled.backgroundColor = BoothTheme.barShade
        scrolled.shadowColor = .clear

        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()

        for appearance in [scrolled, edge] {
            appearance.titleTextAttributes = [.foregroundColor: BoothTheme.onBackground, .font: BoothTheme.font(17, .heavy)]
            appearance.largeTitleTextAttributes = [.foregroundColor: BoothTheme.onBackground, .font: BoothTheme.font(34, .heavy)]
            if #available(iOS 26.0, *) {
                appearance.subtitleTextAttributes = [.foregroundColor: BoothTheme.accent, .font: BoothTheme.font(13, .semibold)]
                appearance.largeSubtitleTextAttributes = [.foregroundColor: BoothTheme.accent, .font: BoothTheme.font(15, .semibold)]
            }
        }
        navigationItem.standardAppearance = scrolled
        navigationItem.scrollEdgeAppearance = edge
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = BoothTheme.accent
        selectButton.tintColor = BoothTheme.onBackground
        paletteButton.tintColor = BoothTheme.onBackground
        selectButton.setTitleTextAttributes([.font: BoothTheme.font(17, .bold), .foregroundColor: BoothTheme.onBackground], for: .normal)
        selectButton.setTitleTextAttributes([.font: BoothTheme.font(17, .bold), .foregroundColor: BoothTheme.onBackground.withAlphaComponent(0.5)], for: .disabled)
    }

    private func setUpLayout() {
        marquee.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let stack = UIStackView(arrangedSubviews: [marquee, binnyCard, dayBar, filterBar, banner, twinsBanner, collectionView])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(10, after: twinsBanner)
        stack.translatesAutoresizingMaskIntoConstraints = false
        messageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true

        view.addSubview(stack)
        view.addSubview(messageView)
        view.addSubview(loadingView)
        view.addSubview(binButton)
        view.addSubview(sortButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            binnyCard.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            dayBar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            filterBar.widthAnchor.constraint(equalTo: stack.widthAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 38),
            banner.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            twinsBanner.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            messageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            sortButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sortButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            binButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            binButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        stack.alignment = .center
        marquee.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        collectionView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        setContentScrollView(collectionView)
    }

    private func makeLayout() -> UICollectionViewLayout {
        let headerHeight = FolderBackgroundView.tabHeight
        let gap: CGFloat = 26
        let margin = Metrics.margin
        let spacing = Metrics.spacing
        let padding = Metrics.padding

        let layout = UICollectionViewCompositionalLayout { _, environment in
            let width = environment.container.effectiveContentSize.width
            let columns = Self.columns(for: width)

            // Frames are exact squares: strip width minus padding and gaps, split between columns
            let side = (width - 2 * margin - 2 * padding - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columns)), heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(side)),
                repeatingSubitem: item, count: columns)
            group.interItemSpacing = .fixed(spacing)
            group.contentInsets = .init(top: 0, leading: padding, bottom: 0, trailing: padding)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = .init(top: 8, leading: margin, bottom: 8 + gap, trailing: margin)

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight)),
                elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            section.boundarySupplementaryItems = [header]

            let folder = NSCollectionLayoutDecorationItem.background(elementKind: FolderBackgroundView.kind)
            folder.contentInsets = .init(top: 0, leading: margin, bottom: gap, trailing: margin)
            section.decorationItems = [folder]
            return section
        }
        layout.register(FolderBackgroundView.self, forDecorationViewOfKind: FolderBackgroundView.kind)
        return layout
    }

    private static func columns(for width: CGFloat) -> Int { width > 600 ? 5 : 3 }

    /// Pixel size of one photo frame, used for every thumbnail request so the image cache can match.
    private var thumbnailSize: CGSize {
        let width = collectionView.bounds.width
        let columns = CGFloat(Self.columns(for: width))
        let side = (width - 2 * Metrics.margin - 2 * Metrics.padding - Metrics.spacing * (columns - 1)) / columns
        let pixels = side * collectionView.traitCollection.displayScale
        return CGSize(width: pixels, height: pixels)
    }

    private func itemID(at indexPath: IndexPath) -> String? {
        guard sections.indices.contains(indexPath.section),
              sections[indexPath.section].itemIDs.indices.contains(indexPath.item) else { return nil }
        return sections[indexPath.section].itemIDs[indexPath.item]
    }

    // MARK: Folder open / close

    private func toggleFolder(at section: Int) {
        guard !presenter.isSelecting, sections.indices.contains(section) else { return }
        let model = sections[section]
        let paths = model.itemIDs.indices.map { IndexPath(item: $0, section: section) }
        let willCollapse = !collapsedTitles.contains(model.title)

        if willCollapse {
            collapsedTitles.insert(model.title)
        } else {
            collapsedTitles.remove(model.title)
            model.itemIDs.forEach { poppedIDs.remove($0) } // photos pop out again
        }

        let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader,
                                                      at: IndexPath(item: 0, section: section)) as? SectionHeaderView
        header?.setCollapsed(willCollapse, animated: true)
        UISelectionFeedbackGenerator().selectionChanged()

        let animations = {
            self.collectionView.performBatchUpdates {
                if willCollapse { self.collectionView.deleteItems(at: paths) } else { self.collectionView.insertItems(at: paths) }
            }
        }
        if UIAccessibility.isReduceMotionEnabled {
            animations()
        } else {
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.4,
                           options: [.allowUserInteraction], animations: animations)
        }
        refreshFoldBar()
    }

    private var allFoldersCollapsed: Bool {
        !sections.isEmpty && sections.allSatisfy { collapsedTitles.contains($0.title) }
    }

    private func refreshFoldBar() {
        dayBar.updateFold(folderCount: sections.count, allCollapsed: allFoldersCollapsed, isEnabled: !presenter.isSelecting)
    }

    private func setAllFolders(collapsed: Bool) {
        guard !presenter.isSelecting else { return }
        var paths: [IndexPath] = []
        var changed: [Int] = []
        for (section, model) in sections.enumerated() where collapsedTitles.contains(model.title) != collapsed {
            changed.append(section)
            paths += model.itemIDs.indices.map { IndexPath(item: $0, section: section) }
            if collapsed {
                collapsedTitles.insert(model.title)
            } else {
                collapsedTitles.remove(model.title)
                model.itemIDs.forEach { poppedIDs.remove($0) } // photos pop out again
            }
        }
        guard !changed.isEmpty else { refreshFoldBar(); return }

        for section in changed {
            let header = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader,
                                                          at: IndexPath(item: 0, section: section)) as? SectionHeaderView
            header?.setCollapsed(collapsed, animated: true)
        }
        UISelectionFeedbackGenerator().selectionChanged()

        let animations = {
            self.collectionView.performBatchUpdates {
                if collapsed { self.collectionView.deleteItems(at: paths) } else { self.collectionView.insertItems(at: paths) }
            }
        }
        if UIAccessibility.isReduceMotionEnabled {
            animations()
        } else {
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.4,
                           options: [.allowUserInteraction], animations: animations)
        }
        refreshFoldBar()
        UIAccessibility.post(notification: .announcement, argument: collapsed ? "All folders folded" : "All folders open")
    }

    // MARK: Actions


    @objc private func selectTapped() { presenter.didTapSelect() }
    @objc private func statsTapped() { presenter.didTapStats() }
    @objc private func themesTapped() { ThemePickerViewController.present(from: self) }

    private func updateBinButton(count: Int) {
        binButton.accessibilityLabel = "Bin \(count) selected photo\(count == 1 ? "" : "s")"
        let title = "Bin it · \(count)"
        binButton.configuration?.attributedTitle = AttributedString(
            title, attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))

        let shouldShow = count > 0
        if shouldShow { binButton.isHidden = false }
        let reduce = UIAccessibility.isReduceMotionEnabled
        let targetTransform = shouldShow ? CGAffineTransform.identity : CGAffineTransform(translationX: 0, y: 30)
        if shouldShow && binButton.alpha == 0 && !reduce { binButton.transform = CGAffineTransform(translationX: 0, y: 30) }

        UIView.animate(withDuration: reduce ? 0 : 0.4, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.6) {
            self.binButton.alpha = shouldShow ? 1 : 0
            self.binButton.transform = targetTransform
        } completion: { _ in
            // An earlier, interrupted animation must not hide a button that is meant to be shown
            if self.binButton.alpha == 0 { self.binButton.isHidden = true }
        }
    }
}

// MARK: - OnThisDayViewProtocol

extension OnThisDayViewController: OnThisDayViewProtocol {

    func show(dateText: String) {
        if #available(iOS 26.0, *) {
            navigationItem.subtitle = dateText
        } else {
            navigationItem.prompt = dateText
        }
    }

    func show(quote: String) {
        binnyCard.say(quote)
    }

    func show(stats: BoothStats) {
        binnyCard.setStats(stats)
    }

    func show(twins model: BannerViewModel?) {
        twinsBanner.isHidden = model == nil
        if let model { twinsBanner.configure(model) }
    }

    func select(ids: Set<String>) {
        // Open every folder so the ticked photos are all visible
        collapsedTitles.removeAll()
        collectionView.reloadData()
        collectionView.allowsMultipleSelection = true
        var first: IndexPath?
        for (section, model) in sections.enumerated() {
            for (item, id) in model.itemIDs.enumerated() where ids.contains(id) {
                let path = IndexPath(item: item, section: section)
                collectionView.selectItem(at: path, animated: false, scrollPosition: [])
                first = first ?? path
            }
        }
        selectButton.title = "Cancel"
        updateBinButton(count: ids.count)
        updateSortButton()
        if let first { collectionView.scrollToItem(at: first, at: .centeredVertically, animated: true) }
        refreshFoldBar()
    }

    func showCelebration(text: String) {
        binnyCard.say(text)
        binnyCard.celebrate()
        CelebrationOverlay.show(text: text, in: view)
    }

    func show(sortAvailable: Bool) {
        self.sortAvailable = sortAvailable
        updateSortButton()
    }

    func show(days: [DayChipViewModel], selected: Int) {
        dayBar.configure(days: days, selected: selected)
    }

    func show(filters: [FilterChipViewModel], selected: MediaFilter) {
        let changed = filterBar.selected != selected
        filterBar.configure(chips: filters, selected: selected)
        if changed {
            // A different type is a different list, so start from the top with every folder open
            collapsedTitles.removeAll()
            poppedIDs.removeAll()
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
        }
    }

    func show(isLoading: Bool) {
        loadingView.setLoading(isLoading)
    }

    func show(sections: [SectionViewModel]) {
        self.sections = sections
        let titles = Set(sections.map(\.title))
        collapsedTitles.formIntersection(titles)
        if sections.isEmpty { poppedIDs.removeAll() }
        collectionView.reloadData()
        selectButton.isEnabled = !sections.isEmpty
        refreshFoldBar()
    }

    func show(message: MessageViewModel?) {
        messageView.isHidden = message == nil
        if let message { messageView.configure(message) }
    }

    func show(banner model: BannerViewModel?) {
        banner.isHidden = model == nil
        if let model { banner.configure(model) }
    }

    func setSelection(active: Bool, count: Int) {
        if active && count == 0 && !collapsedTitles.isEmpty {
            // Pressing Select: hidden photos can't be picked, so open every folder first
            collapsedTitles.removeAll()
            collectionView.reloadData()
        }
        collectionView.allowsMultipleSelection = active
        if !active {
            collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }
        }
        selectButton.title = active ? "Cancel" : "Select"
        updateBinButton(count: count)
        updateSortButton()
        refreshFoldBar()
    }

    func thumbnailView(for id: String) -> UIView? {
        for (section, model) in sections.enumerated() {
            if let item = model.itemIDs.firstIndex(of: id) {
                return collectionView.cellForItem(at: IndexPath(item: item, section: section))
            }
        }
        return nil
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension OnThisDayViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collapsedTitles.contains(sections[section].title) ? 0 : sections[section].itemIDs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseID, for: indexPath) as! PhotoCell
        let id = sections[indexPath.section].itemIDs[indexPath.item]
        cell.representedID = id
        let model = sections[indexPath.section]
        let badges = model.badges
        let badge = badges.indices.contains(indexPath.item) ? badges[indexPath.item] : .none
        cell.setBadge(badge)
        cell.setStamp(year: model.title)

        let kindText: String
        switch badge {
        case .none: kindText = "Photo"
        case .live: kindText = "Live Photo"
        case .video(let duration): kindText = "Video, \(duration)"
        }
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(kindText) from \(model.title), \(indexPath.item + 1) of \(model.itemIDs.count)"
        cell.accessibilityHint = presenter.isSelecting ? "Double tap to select or deselect" : "Double tap to open"
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Keep") { [weak self] _ in self?.presenter.didRequestKeep(id: id); return true },
            UIAccessibilityCustomAction(name: "Bin") { [weak self] _ in self?.presenter.didRequestBin(id: id); return true }
        ]
        cell.thumbnailToken = presenter.loadThumbnail(id: id, targetSize: thumbnailSize) { [weak cell] image in
            guard let cell, cell.representedID == id else { return }
            cell.setImage(image)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseID, for: indexPath) as! SectionHeaderView
        let model = sections[indexPath.section]
        header.configure(model, collapsed: collapsedTitles.contains(model.title))
        header.onTap = { [weak self] in
            guard let self, let section = self.sections.firstIndex(where: { $0.title == model.title }) else { return }
            self.toggleFolder(at: section)
        }
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension OnThisDayViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? PhotoCell, let id = itemID(at: indexPath),
              !UIAccessibility.isReduceMotionEnabled, poppedIDs.insert(id).inserted else { return }
        // Photos pop out of the folder one after another
        cell.popIn(delay: Double(indexPath.item % 6) * 0.04, tilt: indexPath.item.isMultiple(of: 2) ? -0.12 : 0.12)
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? PhotoCell, let token = cell.thumbnailToken else { return }
        presenter.cancelThumbnail(token)
        cell.thumbnailToken = nil
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard presenter.isSelecting else {
            // Not selecting: a tap opens the photo instead
            if let id = itemID(at: indexPath) { presenter.didTapPhoto(id: id) }
            return false
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        feedback.selectionChanged()
        presenter.didSelect(id: sections[indexPath.section].itemIDs[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        presenter.didDeselect(id: sections[indexPath.section].itemIDs[indexPath.item])
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension OnThisDayViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        presenter.startCaching(ids: indexPaths.compactMap(itemID(at:)), targetSize: thumbnailSize)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        presenter.stopCaching(ids: indexPaths.compactMap(itemID(at:)), targetSize: thumbnailSize)
    }
}

#Preview {
    OnThisDayRouter.makeModule()
}
