import UIKit

// MARK: - Photo frame

final class PhotoCell: UICollectionViewCell {
    static let reuseID = "PhotoCell"

    private let imageView = UIImageView()
    private let tintView = UIView()
    private let badge = UIImageView()
    private let badgeBackground = UIView()
    private let mediaBadge = UIView()
    private let mediaIcon = UIImageView()
    private let mediaLabel = UILabel()
    private let stampLabel = UILabel()
    private let darkroomTint = UIView()
    private let sprockets = CAShapeLayer()
    private var imageInsets: [NSLayoutConstraint] = []
    private let style = BoothTheme.current.photoStyle

    var representedID: String?
    var thumbnailToken: ThumbnailToken?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = BoothTheme.current.photoCorner
        imageView.backgroundColor = BoothTheme.photoPlaceholder

        tintView.backgroundColor = BoothTheme.photoTint
        tintView.layer.cornerRadius = BoothTheme.current.photoCorner
        tintView.layer.borderColor = BoothTheme.selection.cgColor
        tintView.layer.borderWidth = 3
        tintView.isHidden = true

        badgeBackground.backgroundColor = BoothTheme.paper
        badgeBackground.layer.cornerRadius = 13
        badgeBackground.isHidden = true
        badge.image = UIImage(systemName: "trash.fill")
        badge.tintColor = BoothTheme.ink
        badge.contentMode = .scaleAspectFit

        mediaBadge.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        mediaBadge.layer.cornerRadius = 9
        mediaBadge.isHidden = true
        mediaIcon.tintColor = BoothTheme.onViewer
        mediaIcon.contentMode = .scaleAspectFit
        mediaIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        mediaLabel.font = BoothTheme.font(10, .heavy, scaling: false)
        mediaLabel.textColor = BoothTheme.onViewer
        let mediaStack = UIStackView(arrangedSubviews: [mediaIcon, mediaLabel])
        mediaStack.spacing = 3
        mediaStack.alignment = .center
        mediaStack.translatesAutoresizingMaskIntoConstraints = false
        mediaBadge.addSubview(mediaStack)

        [imageView, tintView, badgeBackground, mediaBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeBackground.addSubview(badge)

        imageInsets = [
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ]
        NSLayoutConstraint.activate(imageInsets + [
            tintView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tintView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            badgeBackground.widthAnchor.constraint(equalToConstant: 26),
            badgeBackground.heightAnchor.constraint(equalToConstant: 26),
            badgeBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            badgeBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            badge.centerXAnchor.constraint(equalTo: badgeBackground.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeBackground.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 14),
            badge.heightAnchor.constraint(equalToConstant: 14),
            mediaBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 5),
            mediaBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            mediaStack.topAnchor.constraint(equalTo: mediaBadge.topAnchor, constant: 3),
            mediaStack.bottomAnchor.constraint(equalTo: mediaBadge.bottomAnchor, constant: -3),
            mediaStack.leadingAnchor.constraint(equalTo: mediaBadge.leadingAnchor, constant: 6),
            mediaStack.trailingAnchor.constraint(equalTo: mediaBadge.trailingAnchor, constant: -6)
        ])
        applyPhotoStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Theme framing

    /// Frames the photo the way the theme asks: a print border, a film frame, a darkroom tint or an EXIF strip.
    private func applyPhotoStyle() {
        func inset(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
            imageInsets[0].constant = top
            imageInsets[1].constant = -bottom
            imageInsets[2].constant = left
            imageInsets[3].constant = -right
        }
        stampLabel.translatesAutoresizingMaskIntoConstraints = false
        stampLabel.font = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        stampLabel.isHidden = true

        switch style {
        case .plain:
            break
        case .print:
            contentView.backgroundColor = .white
            contentView.layer.cornerRadius = 2
            contentView.layer.shadowColor = UIColor.black.cgColor
            contentView.layer.shadowOpacity = 0.25
            contentView.layer.shadowRadius = 2
            contentView.layer.shadowOffset = CGSize(width: 0, height: 1)
            inset(top: 4, left: 4, bottom: 13, right: 4)
        case .film:
            contentView.backgroundColor = .black
            contentView.layer.addSublayer(sprockets)
            sprockets.fillColor = UIColor(hex: 0xF4E3C1).withAlphaComponent(0.9).cgColor
            inset(top: 10, left: 3, bottom: 10, right: 3)
            stampLabel.textColor = UIColor(hex: 0xFF7A1A)
            stampLabel.layer.shadowColor = UIColor(hex: 0xFF7A1A).cgColor
            stampLabel.layer.shadowOpacity = 0.9
            stampLabel.layer.shadowRadius = 3
            stampLabel.layer.shadowOffset = .zero
        case .darkroom:
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = UIColor(hex: 0x6A1E1E).cgColor
            darkroomTint.backgroundColor = UIColor(hex: 0xE02A1E)
            darkroomTint.layer.compositingFilter = "colorBlendMode"
            darkroomTint.isUserInteractionEnabled = false
            darkroomTint.translatesAutoresizingMaskIntoConstraints = false
            contentView.insertSubview(darkroomTint, aboveSubview: imageView)
            NSLayoutConstraint.activate([
                darkroomTint.topAnchor.constraint(equalTo: imageView.topAnchor),
                darkroomTint.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
                darkroomTint.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
                darkroomTint.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
            ])
            stampLabel.textColor = UIColor(hex: 0xFF6A6A)
        case .exif:
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = UIColor(hex: 0x4A4A4E).cgColor
            contentView.layer.cornerRadius = 3
            contentView.clipsToBounds = true
            stampLabel.text = "f/1.8 · 1/250 · ISO100"
            stampLabel.font = UIFont.monospacedSystemFont(ofSize: 6.5, weight: .regular)
            stampLabel.textColor = UIColor(hex: 0xE8E8EA)
            stampLabel.backgroundColor = UIColor.black.withAlphaComponent(0.73)
            stampLabel.textAlignment = .center
            stampLabel.isHidden = false
        }

        guard style == .film || style == .darkroom || style == .exif else { return }
        contentView.addSubview(stampLabel)
        switch style {
        case .film:
            NSLayoutConstraint.activate([
                stampLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -4),
                stampLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -4)
            ])
        case .darkroom:
            NSLayoutConstraint.activate([
                stampLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 4),
                stampLabel.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 3)
            ])
        default:
            NSLayoutConstraint.activate([
                stampLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                stampLabel.heightAnchor.constraint(equalToConstant: 12)
            ])
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard style == .film else { return }
        let bounds = contentView.bounds
        let path = UIBezierPath()
        var x: CGFloat = 3
        while x + 5 <= bounds.width - 3 {
            path.append(UIBezierPath(roundedRect: CGRect(x: x, y: 2, width: 5, height: 5), cornerRadius: 1))
            path.append(UIBezierPath(roundedRect: CGRect(x: x, y: bounds.height - 7, width: 5, height: 5), cornerRadius: 1))
            x += 11
        }
        sprockets.path = path.cgPath
    }

    /// The year folder the photo sits in becomes the date printed on it, for themes that stamp their prints.
    func setStamp(year: String) {
        guard style == .film || style == .darkroom, year.count == 4, let digits = Int(year) else {
            if style == .film || style == .darkroom { stampLabel.isHidden = true }
            return
        }
        let day = Date.now.formatted(.dateTime.month(.twoDigits).day(.twoDigits)).replacingOccurrences(of: "/", with: " ")
        stampLabel.text = "\u{2019}\(String(format: "%02d", digits % 100)) \(day)"
        stampLabel.isHidden = false
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { isSelected ? [.button, .selected] : .button }
        set { }
    }

    override var isSelected: Bool {
        didSet {
            tintView.isHidden = !isSelected
            badgeBackground.isHidden = !isSelected
            if isSelected && !oldValue && !UIAccessibility.isReduceMotionEnabled { animateBadge() }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        representedID = nil
        thumbnailToken = nil
        contentView.layer.removeAnimation(forKey: "pop")
        badgeBackground.layer.removeAnimation(forKey: "badge")
    }

    // Animations below run on the layer only, so the view's real transform, alpha and
    // touch handling stay untouched and the cell is tappable the whole time.

    /// The photo pops out of the folder with a small tilt.
    func popIn(delay: CFTimeInterval, tilt: CGFloat) {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.55
        spring.toValue = 1
        spring.damping = 14
        spring.stiffness = 220
        spring.mass = 1
        spring.duration = spring.settlingDuration

        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = tilt
        rotate.toValue = 0
        rotate.duration = 0.35
        rotate.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.2

        let group = CAAnimationGroup()
        group.animations = [spring, rotate, fade]
        group.duration = spring.duration
        group.beginTime = CACurrentMediaTime() + delay
        group.fillMode = .backwards
        contentView.layer.add(group, forKey: "pop")
    }

    private func animateBadge() {
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.3
        spring.toValue = 1
        spring.damping = 9
        spring.stiffness = 260
        spring.mass = 1
        spring.duration = spring.settlingDuration
        badgeBackground.layer.add(spring, forKey: "badge")
    }

    func setImage(_ image: UIImage?) { imageView.image = image }

    func setBadge(_ badge: ItemBadge) {
        switch badge {
        case .none:
            mediaBadge.isHidden = true
        case .live:
            mediaBadge.isHidden = false
            mediaIcon.image = UIImage(systemName: "livephoto")
            mediaLabel.text = "LIVE"
        case .video(let duration):
            mediaBadge.isHidden = false
            mediaIcon.image = UIImage(systemName: "play.fill")
            mediaLabel.text = duration
        }
    }
}

// MARK: - Year tab (sits on the folder)

final class SectionHeaderView: UICollectionReusableView {
    static let reuseID = "SectionHeaderView"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = BoothTheme.font(22, .heavy, maxScale: 1.1)
        titleLabel.textColor = BoothTheme.ink
        subtitleLabel.font = BoothTheme.font(13, .semibold, maxScale: 1.3)
        subtitleLabel.textColor = BoothTheme.accent
        chevron.tintColor = BoothTheme.ink
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .heavy)

        [titleLabel, chevron, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: FolderBackgroundView.tabHeight / 2 + 2),
            chevron.trailingAnchor.constraint(equalTo: leadingAnchor, constant: FolderBackgroundView.tabWidth - 14),
            chevron.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: FolderBackgroundView.tabWidth + 10),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            subtitleLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?() }

    func configure(_ model: SectionViewModel, collapsed: Bool) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        accessibilityLabel = "\(model.title), \(model.subtitle)"
        accessibilityValue = collapsed ? "Closed" : "Open"
        setCollapsed(collapsed, animated: false)
    }

    func setCollapsed(_ collapsed: Bool, animated: Bool) {
        accessibilityValue = collapsed ? "Closed" : "Open"
        let transform = collapsed ? CGAffineTransform(rotationAngle: -.pi / 2) : .identity
        guard animated, !UIAccessibility.isReduceMotionEnabled else { chevron.transform = transform; return }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            self.chevron.transform = transform
        }
    }
}

// MARK: - Folder behind each year

final class FolderBackgroundView: UICollectionReusableView {
    static let kind = "folder-background"
    static let tabWidth: CGFloat = 132
    static let tabHeight: CGFloat = 38

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tabH = Self.tabHeight

        // Back panel with the tab, then the lighter front panel on top of it
        let tab = makePanel(color: BoothTheme.folderBack, radius: 12)
        tab.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let backBody = makePanel(color: BoothTheme.folderBack, radius: 12)
        let front = makePanel(color: BoothTheme.strip, radius: 12)
        front.layer.shadowOpacity = 0
        backBody.layer.shadowOpacity = 0.3

        NSLayoutConstraint.activate([
            tab.topAnchor.constraint(equalTo: topAnchor),
            tab.leadingAnchor.constraint(equalTo: leadingAnchor),
            tab.widthAnchor.constraint(equalToConstant: Self.tabWidth),
            tab.heightAnchor.constraint(equalToConstant: tabH + 14),
            backBody.topAnchor.constraint(equalTo: topAnchor, constant: tabH - 6),
            backBody.leadingAnchor.constraint(equalTo: leadingAnchor),
            backBody.trailingAnchor.constraint(equalTo: trailingAnchor),
            backBody.bottomAnchor.constraint(equalTo: bottomAnchor),
            front.topAnchor.constraint(equalTo: topAnchor, constant: tabH),
            front.leadingAnchor.constraint(equalTo: leadingAnchor),
            front.trailingAnchor.constraint(equalTo: trailingAnchor),
            front.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makePanel(color: UIColor, radius: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = radius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 8
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        return view
    }
}

// MARK: - Marquee (the decoration row under the title)

final class MarqueeView: UIView {
    private let replicator = CAReplicatorLayer()
    private let bulb = CALayer()
    private let line = CAShapeLayer()
    private let style = BoothTheme.current.divider
    private let spacing: CGFloat = 22

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        switch style {
        case .bulbs: setUpBulbs()
        case .none: break
        default:
            line.fillColor = nil
            line.lineCap = .round
            layer.addSublayer(line)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpBulbs() {
        bulb.bounds = CGRect(x: 0, y: 0, width: 8, height: 8)
        bulb.cornerRadius = 4
        bulb.backgroundColor = BoothTheme.accent.cgColor
        bulb.shadowColor = BoothTheme.accent.cgColor
        bulb.shadowOpacity = 1
        bulb.shadowRadius = 4
        bulb.shadowOffset = .zero

        replicator.addSublayer(bulb)
        replicator.instanceTransform = CATransform3DMakeTranslation(spacing, 0, 0)
        replicator.instanceDelay = 0.25
        layer.addSublayer(replicator)

        if !UIAccessibility.isReduceMotionEnabled {
            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = 1
            twinkle.toValue = 0.25
            twinkle.duration = 0.7
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            bulb.add(twinkle, forKey: "twinkle")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switch style {
        case .bulbs:
            let count = max(Int((bounds.width - 16) / spacing), 1)
            let usedWidth = CGFloat(count - 1) * spacing
            replicator.frame = bounds
            replicator.instanceCount = count
            bulb.position = CGPoint(x: (bounds.width - usedWidth) / 2, y: bounds.midY)
        case .none:
            break
        default:
            drawLine()
        }
    }

    private func drawLine() {
        let color = BoothTheme.onBackground
        let inset: CGFloat = 4
        let width = bounds.width - 2 * inset
        let midY = bounds.midY
        let path = UIBezierPath()
        line.frame = bounds
        line.lineDashPattern = nil
        line.fillColor = nil
        line.lineWidth = 2

        switch style {
        case .stitch:
            path.move(to: CGPoint(x: inset, y: midY))
            path.addLine(to: CGPoint(x: inset + width, y: midY))
            line.lineDashPattern = [6, 5]
            line.lineWidth = 2.5
            line.strokeColor = color.withAlphaComponent(0.45).cgColor
        case .ticks:
            path.move(to: CGPoint(x: inset, y: midY + 3))
            path.addLine(to: CGPoint(x: inset + width, y: midY + 3))
            var x = inset
            while x <= inset + width {
                path.move(to: CGPoint(x: x, y: midY + 3))
                path.addLine(to: CGPoint(x: x, y: midY - 3))
                x += 14
            }
            line.lineWidth = 1
            line.lineCap = .butt
            line.strokeColor = color.withAlphaComponent(0.7).cgColor
        case .waves:
            var x = inset
            while x + 16 <= inset + width {
                path.append(UIBezierPath(arcCenter: CGPoint(x: x + 8, y: midY - 2), radius: 5.5,
                                         startAngle: 0, endAngle: .pi, clockwise: true))
                x += 16
            }
            line.lineWidth = 1.8
            line.strokeColor = color.withAlphaComponent(0.55).cgColor
        case .pixels, .sprockets:
            let count = max(Int(width / 14), 2)
            let step = (width - 8) / CGFloat(count - 1)
            for index in 0..<count {
                let rect = style == .pixels
                    ? CGRect(x: inset + CGFloat(index) * step, y: midY - 4, width: 8, height: 8)
                    : CGRect(x: inset + CGFloat(index) * step, y: midY - 3, width: 9, height: 6)
                path.append(UIBezierPath(roundedRect: rect, cornerRadius: style == .pixels ? 0 : 2))
            }
            line.lineWidth = 0
            line.fillColor = color.withAlphaComponent(style == .pixels ? 0.85 : 0.9).cgColor
            line.strokeColor = nil
        default:
            break
        }
        line.path = path.cgPath
    }
}

// MARK: - Limited access banner

final class BannerView: UIView {
    var onTap: (() -> Void)?
    private let label = UILabel()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = BoothTheme.paper
        layer.cornerRadius = 14

        label.font = BoothTheme.font(13, .semibold)
        label.textColor = BoothTheme.ink
        label.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = BoothTheme.ink
        config.baseForegroundColor = BoothTheme.paper
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ model: BannerViewModel) {
        label.text = model.text
        button.configuration?.attributedTitle = AttributedString(
            model.actionTitle, attributes: AttributeContainer([.font: BoothTheme.font(13, .bold)]))
    }
}

// MARK: - Empty / no-access message

final class MessageView: UIView {
    var onAction: (() -> Void)?
    private let iconView = UIImageView()
    private let label = UILabel()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let circle = UIView()
        circle.backgroundColor = BoothTheme.paper
        circle.layer.cornerRadius = 44
        circle.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = BoothTheme.ink
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 36, weight: .bold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(iconView)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 88),
            circle.heightAnchor.constraint(equalToConstant: 88),
            iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])

        label.font = BoothTheme.font(17, .semibold)
        label.textColor = BoothTheme.onBackground
        label.numberOfLines = 0
        label.textAlignment = .center

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = BoothTheme.primary
        config.baseForegroundColor = BoothTheme.onPrimary
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [circle, label, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ model: MessageViewModel) {
        iconView.image = UIImage(systemName: model.icon)
        label.text = model.text
        button.isHidden = model.actionTitle == nil
        button.configuration?.attributedTitle = AttributedString(
            model.actionTitle ?? "", attributes: AttributeContainer([.font: BoothTheme.font(16, .bold)]))
    }
}

// MARK: - Loading

final class LoadingView: UIView {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        spinner.color = BoothTheme.onBackground

        label.text = "Developing your photos…"
        label.font = BoothTheme.font(17, .semibold)
        label.textColor = BoothTheme.onBackground

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setLoading(_ loading: Bool) {
        isHidden = !loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
    }
}
