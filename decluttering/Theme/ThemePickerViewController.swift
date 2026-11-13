import UIKit

/// Bottom sheet with a swipeable row of looks. Tapping one applies it straight away.
final class ThemePickerViewController: UIViewController {

    private let themes = ThemeCatalog.all
    private let titleLabel = UILabel()
    private let noteLabel = UILabel()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 150, height: 290)
        layout.minimumLineSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(ThemeCardCell.self, forCellWithReuseIdentifier: ThemeCardCell.reuseID)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()

    static func present(from presenter: UIViewController) {
        let host = presenter.view.window?.rootViewController ?? presenter
        let top = host.presentedViewController ?? host
        guard !(top is ThemePickerViewController) else { return }
        let picker = ThemePickerViewController()
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.custom { _ in 420 }]
            sheet.prefersGrabberVisible = true
        }
        top.present(picker, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1F1F24)

        titleLabel.text = "Pick a look"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        noteLabel.text = "Tap one to try it. Swipe for more."
        noteLabel.font = .systemFont(ofSize: 14, weight: .regular)
        noteLabel.textColor = UIColor.white.withAlphaComponent(0.65)

        let header = UIStackView(arrangedSubviews: [titleLabel, noteLabel])
        header.axis = .vertical
        header.spacing = 2
        [header, collectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            collectionView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let index = themes.firstIndex(where: { $0.id == ThemeStore.current.id }) {
            collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
        }
    }

    /// The home screen icon only changes once the sheet is closed, because iOS shows an alert on every change.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        let app = UIApplication.shared
        let wanted = ThemeStore.current.iconName
        guard app.supportsAlternateIcons, app.alternateIconName != wanted else { return }
        app.setAlternateIconName(wanted)
    }
}

extension ThemePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { themes.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThemeCardCell.reuseID, for: indexPath) as! ThemeCardCell
        let theme = themes[indexPath.item]
        cell.configure(theme, isCurrent: theme.id == ThemeStore.current.id)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        ThemeStore.select(themes[indexPath.item])
        UISelectionFeedbackGenerator().selectionChanged()
        collectionView.visibleCells.forEach { cell in
            guard let cell = cell as? ThemeCardCell, let path = collectionView.indexPath(for: cell) else { return }
            cell.setCurrent(themes[path.item].id == ThemeStore.current.id)
        }
    }
}

// MARK: - Card

private final class ThemeCardCell: UICollectionViewCell {
    static let reuseID = "ThemeCardCell"

    private let preview = ThemePreviewView()
    private let nameLabel = UILabel()
    private let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8
        check.tintColor = .white
        check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        check.layer.shadowColor = UIColor.black.cgColor
        check.layer.shadowOpacity = 0.5
        check.layer.shadowRadius = 4
        check.layer.shadowOffset = .zero

        preview.layer.cornerRadius = 22
        preview.layer.cornerCurve = .continuous
        preview.clipsToBounds = true
        preview.layer.borderWidth = 3

        [preview, nameLabel, check].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            preview.heightAnchor.constraint(equalToConstant: 252),
            nameLabel.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            check.topAnchor.constraint(equalTo: preview.topAnchor, constant: 8),
            check.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ theme: Theme, isCurrent: Bool) {
        preview.configure(theme)
        nameLabel.text = theme.name
        isAccessibilityElement = true
        accessibilityLabel = theme.name
        accessibilityHint = theme.tagline
        setCurrent(isCurrent)
    }

    func setCurrent(_ current: Bool) {
        check.isHidden = !current
        preview.layer.borderColor = (current ? UIColor.white : UIColor.white.withAlphaComponent(0.12)).cgColor
        accessibilityTraits = current ? [.button, .selected] : .button
    }
}

// MARK: - Mini home screen

/// A tiny home screen drawn in one theme's colours, regardless of which theme is active.
private final class ThemePreviewView: UIView {
    private var theme: Theme?
    private let title = UILabel()
    private let bubble = UIView()
    private let chips = [UIView(), UIView(), UIView()]
    private let folder = UIView()
    private let tiles = [UIView(), UIView(), UIView()]
    private let button = UILabel()
    private let tileColors = [UIColor(hex: 0xF4A58A), UIColor(hex: 0x8FD3A0), UIColor(hex: 0xB9A5F0)]

    override init(frame: CGRect) {
        super.init(frame: frame)
        title.text = "On This Day"
        button.text = "Swipe sort"
        button.textAlignment = .center
        button.clipsToBounds = true
        [title, bubble, folder, button].forEach(addSubview)
        chips.forEach(addSubview)
        tiles.forEach(folder.addSubview)
        for (index, tile) in tiles.enumerated() { tile.backgroundColor = tileColors[index] }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ theme: Theme) {
        self.theme = theme
        backgroundColor = BoothTheme.background(of: theme)
        title.font = BoothTheme.font(17, .heavy, in: theme)
        title.textColor = theme.onBackground
        bubble.backgroundColor = theme.paper
        for (index, chip) in chips.enumerated() {
            chip.backgroundColor = index == 0 ? theme.primary : theme.chipFill
        }
        folder.backgroundColor = theme.strip
        button.font = BoothTheme.font(12, .heavy, in: theme)
        button.textColor = theme.onPrimary
        button.backgroundColor = theme.primary
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let theme else { return }
        let w = bounds.width, pad: CGFloat = 12
        title.frame = CGRect(x: pad, y: 18, width: w - 2 * pad, height: 22)
        bubble.frame = CGRect(x: pad, y: 52, width: w - 2 * pad, height: 36)
        bubble.layer.cornerRadius = 10
        let chipW = (w - 2 * pad - 12) / 3
        for (index, chip) in chips.enumerated() {
            chip.frame = CGRect(x: pad + CGFloat(index) * (chipW + 6), y: 100, width: chipW, height: 16)
            chip.layer.cornerRadius = 8
        }
        folder.frame = CGRect(x: pad, y: 128, width: w - 2 * pad, height: 66)
        folder.layer.cornerRadius = min(theme.photoCorner * 2 + 4, 14)
        let tileW = (folder.bounds.width - 5 * 4) / 3
        for (index, tile) in tiles.enumerated() {
            tile.frame = CGRect(x: 5 + CGFloat(index) * (tileW + 5), y: 5, width: tileW, height: folder.bounds.height - 10)
            tile.layer.cornerRadius = theme.photoCorner
        }
        button.frame = CGRect(x: (w - 92) / 2, y: bounds.height - 44, width: 92, height: 28)
        button.layer.cornerRadius = 14
    }
}
