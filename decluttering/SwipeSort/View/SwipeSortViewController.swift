import UIKit

// MARK: - One card

final class SortCardView: UIView {

    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let keepStamp = UILabel()
    private let binStamp = UILabel()
    private let kindBadge = UILabel()

    private(set) var representedID: String?
    private var token: ThumbnailToken?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = BoothTheme.surface
        layer.cornerRadius = 22
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = BoothTheme.folderBack

        titleLabel.font = BoothTheme.font(20, .heavy, maxScale: 1.3)
        titleLabel.textColor = BoothTheme.ink
        subtitleLabel.font = BoothTheme.font(13, .semibold, maxScale: 1.3)
        subtitleLabel.textColor = BoothTheme.ink.withAlphaComponent(0.7)

        for (stamp, text, fill, ink) in [(keepStamp, "KEEP", BoothTheme.accent, BoothTheme.accent.readableOn),
                                         (binStamp, "BIN", BoothTheme.ink, BoothTheme.paper)] {
            stamp.text = text
            stamp.font = BoothTheme.font(26, .black, scaling: false)
            stamp.textColor = ink
            stamp.backgroundColor = fill
            stamp.textAlignment = .center
            stamp.layer.cornerRadius = 10
            stamp.layer.borderColor = ink.cgColor
            stamp.layer.borderWidth = 3
            stamp.clipsToBounds = true
            stamp.alpha = 0
            stamp.translatesAutoresizingMaskIntoConstraints = false
        }
        keepStamp.transform = CGAffineTransform(rotationAngle: -0.2)
        binStamp.transform = CGAffineTransform(rotationAngle: 0.2)

        kindBadge.font = BoothTheme.font(11, .heavy, scaling: false)
        kindBadge.textColor = BoothTheme.onViewer
        kindBadge.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        kindBadge.textAlignment = .center
        kindBadge.layer.cornerRadius = 9
        kindBadge.clipsToBounds = true
        kindBadge.isHidden = true
        kindBadge.translatesAutoresizingMaskIntoConstraints = false

        let texts = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        texts.axis = .vertical
        [imageView, texts].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(imageView)
        addSubview(texts)
        addSubview(keepStamp)
        addSubview(binStamp)
        addSubview(kindBadge)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            imageView.bottomAnchor.constraint(equalTo: texts.topAnchor, constant: -12),
            texts.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            texts.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            texts.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            keepStamp.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 22),
            keepStamp.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 18),
            keepStamp.widthAnchor.constraint(equalToConstant: 100),
            keepStamp.heightAnchor.constraint(equalToConstant: 46),
            binStamp.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 22),
            binStamp.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -18),
            binStamp.widthAnchor.constraint(equalToConstant: 84),
            binStamp.heightAnchor.constraint(equalToConstant: 46),
            kindBadge.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 10),
            kindBadge.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10),
            kindBadge.heightAnchor.constraint(equalToConstant: 20),
            kindBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: ViewerItem, position: String?, loader: (String, CGSize, @escaping (UIImage?) -> Void) -> ThumbnailToken?,
                   cancel: (ThumbnailToken) -> Void) {
        if let token { cancel(token) }
        representedID = item.id
        imageView.image = nil
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        setStamp(0)
        switch item.kind {
        case .photo: kindBadge.isHidden = true
        case .livePhoto: kindBadge.isHidden = false; kindBadge.text = " LIVE "
        case .video: kindBadge.isHidden = false; kindBadge.text = " VIDEO "
        }
        isAccessibilityElement = true
        accessibilityLabel = "\(item.kind == .video ? "Video" : "Photo") from \(item.title), \(item.subtitle)\(position.map { ", \($0)" } ?? "")"

        let scale = traitCollection.displayScale
        let id = item.id
        token = loader(id, CGSize(width: 700 * scale / 2, height: 800 * scale / 2)) { [weak self] image in
            guard let self, self.representedID == id, let image else { return }
            self.imageView.image = image
        }
    }

    /// -1 (full bin) to 1 (full keep).
    func setStamp(_ progress: CGFloat) {
        keepStamp.alpha = max(0, min(progress * 1.6, 1))
        binStamp.alpha = max(0, min(-progress * 1.6, 1))
    }
}

// MARK: - Screen

final class SwipeSortViewController: UIViewController {

    var presenter: SwipeSortPresenterProtocol!

    private let cardArea = UIView()
    private var frontCard = SortCardView()
    private var backCard = SortCardView()
    private let positionLabel = UILabel()
    private let summaryView = UIView()
    private let summaryTitle = UILabel()
    private let summaryDetail = UILabel()
    private let summaryStack = UIStackView()
    private var currentPosition: String?

    private lazy var closeButton = makeRoundButton(symbol: "xmark", label: "Close", fill: BoothTheme.paper, ink: BoothTheme.ink, size: 44) { [weak self] in
        self?.presenter.didTapClose()
    }
    private lazy var undoButton = makeRoundButton(symbol: "arrow.uturn.backward", label: "Undo", fill: BoothTheme.paper, ink: BoothTheme.ink, size: 44) { [weak self] in
        self?.presenter.didTapUndo()
    }
    private lazy var binButton = makeRoundButton(symbol: "trash.fill", label: "Bin this one", fill: BoothTheme.ink, ink: BoothTheme.paper, size: 68, stroke: true) { [weak self] in
        self?.decide(.bin)
    }
    private lazy var keepButton = makeRoundButton(symbol: "heart.fill", label: "Keep this one", fill: BoothTheme.paper, ink: BoothTheme.ink, size: 68) { [weak self] in
        self?.decide(.keep)
    }

    private var isAnimating = false

    // WHIMSY STEP 1 (UIKit Dynamics): the "physics world". It lives inside `cardArea`, so card positions
    // are measured in that view's coordinates. Behaviours (attachment, launch) are added to it and it
    // then moves the card 60 times a second by itself.
    private lazy var animator: UIDynamicAnimator = {
        let animator = UIDynamicAnimator(referenceView: cardArea)
        animator.delegate = self
        return animator
    }()
    private var holdBehavior: UIAttachmentBehavior?
    private var grabOffset = UIOffset.zero
    private var isDragging = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = BoothTheme.interfaceStyle
        view.backgroundColor = BoothTheme.background
        setUpLayout()
        presenter.viewDidLoad()
    }

    // MARK: Setup

    private func makeRoundButton(symbol: String, label: String, fill: UIColor, ink: UIColor, size: CGFloat, stroke: Bool = false,
                                 action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.baseBackgroundColor = fill
        config.baseForegroundColor = ink
        config.cornerStyle = .capsule
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: size > 50 ? 26 : 16, weight: .bold)
        if stroke {
            config.background.strokeColor = BoothTheme.onBackground
            config.background.strokeWidth = 3
        }
        let button = UIButton(configuration: config)
        button.accessibilityLabel = label
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        return button
    }

    private func setUpLayout() {
        positionLabel.font = BoothTheme.font(16, .heavy, maxScale: 1.3)
        positionLabel.textColor = BoothTheme.onBackground
        positionLabel.textAlignment = .center
        positionLabel.translatesAutoresizingMaskIntoConstraints = false

        cardArea.translatesAutoresizingMaskIntoConstraints = false

        // WHIMSY STEP 0 (UIKit Dynamics): the physics engine moves views by changing their `center` and
        // `transform`. Auto Layout would fight that and snap the cards back, so the cards are NOT given
        // constraints. They are sized and centred by hand in `place(_:)` instead.
        for card in [backCard, frontCard] {
            cardArea.addSubview(card)
        }
        backCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        cardArea.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(panned(_:))))

        let actions = UIStackView(arrangedSubviews: [binButton, keepButton])
        actions.spacing = 56
        actions.translatesAutoresizingMaskIntoConstraints = false

        [closeButton, positionLabel, undoButton, cardArea, actions].forEach { view.addSubview($0) }

        // Swiping is the fast way; the buttons are there for VoiceOver, Switch Control and tired thumbs
        let hint = UILabel()
        hint.text = "Swipe right to keep, left to bin"
        hint.font = BoothTheme.font(13, .semibold, maxScale: 1.3)
        hint.textColor = BoothTheme.accent
        hint.textAlignment = .center
        hint.isAccessibilityElement = false
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        configureSummary()

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            undoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            undoButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            positionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            positionLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            cardArea.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 18),
            cardArea.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            cardArea.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -14),

            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -14),
            actions.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actions.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14)
        ])
    }

    private func configureSummary() {
        summaryView.isHidden = true
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryView)

        summaryTitle.font = BoothTheme.font(30, .heavy, maxScale: 1.3)
        summaryTitle.textColor = BoothTheme.onBackground
        summaryTitle.textAlignment = .center
        summaryTitle.numberOfLines = 0
        summaryDetail.font = BoothTheme.font(17, .semibold)
        summaryDetail.textColor = BoothTheme.accent
        summaryDetail.textAlignment = .center
        summaryDetail.numberOfLines = 0

        summaryStack.axis = .vertical
        summaryStack.alignment = .center
        summaryStack.spacing = 14
        summaryStack.translatesAutoresizingMaskIntoConstraints = false
        summaryView.addSubview(summaryStack)

        NSLayoutConstraint.activate([
            summaryView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            summaryView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            summaryView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            summaryView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            summaryStack.centerYAnchor.constraint(equalTo: summaryView.centerYAnchor, constant: -40),
            summaryStack.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            summaryStack.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor)
        ])
    }

    private func summaryButton(_ title: String, symbol: String?, filled: Bool, action: @escaping () -> Void) -> UIButton {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.image = symbol.flatMap { UIImage(systemName: $0) }
        config.imagePadding = 8
        config.baseBackgroundColor = BoothTheme.primary
        config.baseForegroundColor = filled ? BoothTheme.onPrimary : BoothTheme.onBackground
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        config.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: Gestures

    // ═══════════════════════════════════════════════════════════════════════════════
    // WHIMSY: UIKit Dynamics (UIDynamicAnimator + behaviours)
    //
    // Why: the cards used to follow hand-written maths (translate + rotate). UIKit Dynamics is a small
    // physics engine built into UIKit, so the card now behaves like a real object: it swings on your
    // finger, gets thrown with the speed you flick it at, and wobbles when it settles back.
    // It is part of UIKit already, so no package or new framework is needed.
    //
    // Read the "WHIMSY STEP n" comments in order (STEP 0 and 1 are above, in setUpLayout and the
    // properties):
    //   STEP 2  finger goes down  -> hang the card on the finger with an attachment behaviour
    //   STEP 3  finger moves      -> move the anchor, the engine swings and tilts the card
    //   STEP 4  finger lifts fast -> throw the card with a launch behaviour
    //   STEP 5  finger lifts slow -> a second attachment pulls the card home, with a wobble
    //   STEP 6  engine is at rest -> tidy up the leftovers
    // ═══════════════════════════════════════════════════════════════════════════════

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private var cardCenter: CGPoint { CGPoint(x: cardArea.bounds.midX, y: cardArea.bounds.midY) }

    /// Sizes and centres a card by hand (see STEP 0). Pass `keepTransform` to leave any tilt/scale alone.
    private func place(_ card: SortCardView, keepTransform: Bool = false) {
        let transform = card.transform
        card.transform = .identity
        card.bounds = CGRect(origin: .zero, size: cardArea.bounds.size)
        card.center = cardCenter
        if keepTransform { card.transform = transform }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard animator.behaviors.isEmpty, !isDragging, !isAnimating else { return }
        place(frontCard, keepTransform: true)
        place(backCard, keepTransform: true)
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        guard !isAnimating, summaryView.isHidden else { return }
        if reduceMotion { return pannedWithoutPhysics(gesture) }

        let finger = gesture.location(in: cardArea)

        switch gesture.state {
        case .began:
            // WHIMSY STEP 2: hang the card on the finger. The card is attached at the exact spot that was
            // touched (`offsetFromCenter`), so dragging by a corner makes it swing and rotate like paper.
            isDragging = true
            animator.removeAllBehaviors()
            let touch = gesture.location(in: frontCard)
            grabOffset = UIOffset(horizontal: touch.x - frontCard.bounds.midX, vertical: touch.y - frontCard.bounds.midY)
            let hold = UIAttachmentBehavior(item: frontCard, offsetFromCenter: grabOffset, attachedToAnchor: finger)
            hold.length = 0      // the touched spot sits exactly under the finger
            hold.damping = 0.9   // a little give, so the card feels floaty and not glued on
            hold.frequency = 6   // how tightly it follows
            animator.addBehavior(hold)
            holdBehavior = hold

        case .changed:
            // WHIMSY STEP 3: only the anchor moves. The engine works out the swing, the tilt and the lag.
            holdBehavior?.anchorPoint = finger
            updateDragFeedback()

        case .ended, .cancelled:
            isDragging = false
            if let hold = holdBehavior { animator.removeBehavior(hold) }
            holdBehavior = nil

            let velocity = gesture.velocity(in: cardArea)
            let dx = frontCard.center.x - cardCenter.x
            let width = cardArea.bounds.width
            if dx > width * 0.28 || velocity.x > 900 {
                fling(.keep, velocity: velocity)
            } else if dx < -width * 0.28 || velocity.x < -900 {
                fling(.bin, velocity: velocity)
            } else {
                swingBack()
            }

        default:
            break
        }
    }

    /// Stamps and the card behind follow how far the card has been pulled.
    private func updateDragFeedback() {
        let width = cardArea.bounds.width
        let progress = max(-1, min((frontCard.center.x - cardCenter.x) / (width * 0.5), 1))
        frontCard.setStamp(progress)
        let backScale = 0.94 + 0.06 * abs(progress)
        backCard.transform = CGAffineTransform(scaleX: backScale, y: backScale)
    }

    /// Throws the card off screen. Used by a fast flick and by the Keep and Bin buttons.
    private func fling(_ decision: SortDecision, velocity: CGPoint) {
        guard !isAnimating, summaryView.isHidden else { return }
        isAnimating = true
        let direction: CGFloat = decision == .keep ? 1 : -1
        frontCard.setStamp(direction)
        UIAccessibility.post(notification: .announcement, argument: decision == .keep ? "Kept" : "Binned")

        guard !reduceMotion else {
            UIView.animate(withDuration: 0.15, animations: { self.frontCard.alpha = 0 }) { _ in self.finishFling(decision) }
            return
        }

        // WHIMSY STEP 4: launch the card with the speed of the flick. No resistance means it keeps that
        // speed, plus a spin in the direction it is travelling. Buttons pass zero velocity, so a minimum
        // speed makes sure the card always leaves.
        animator.removeAllBehaviors()
        let launch = UIDynamicItemBehavior(items: [frontCard])
        launch.resistance = 0
        launch.allowsRotation = true
        launch.addLinearVelocity(CGPoint(x: direction * max(abs(velocity.x), 1300), y: velocity.y * 0.4 - 150), for: frontCard)
        launch.addAngularVelocity(direction * 2.5, for: frontCard)

        // `action` runs on every frame of the simulation: fade the card as it leaves, and stop once it is gone.
        var done = false
        launch.action = { [weak self] in
            guard let self, !done else { return }
            let travelled = abs(self.frontCard.center.x - self.cardCenter.x)
            let limit = self.cardArea.bounds.width * 1.1
            self.frontCard.alpha = max(0, 1 - travelled / limit)
            if travelled > limit {
                done = true
                DispatchQueue.main.async { self.finishFling(decision) }
            }
        }
        animator.addBehavior(launch)
    }

    private func finishFling(_ decision: SortDecision) {
        animator.removeAllBehaviors()
        frontCard.alpha = 0
        isAnimating = false
        presenter.didDecide(decision)
    }

    private func swingBack() {
        // WHIMSY STEP 5: not thrown hard enough. A second attachment pulls the touched spot back to where it
        // sits when the card is upright in the middle. It overshoots and wobbles before it settles.
        let home = UIAttachmentBehavior(item: frontCard, offsetFromCenter: grabOffset,
                                        attachedToAnchor: CGPoint(x: cardCenter.x + grabOffset.horizontal,
                                                                  y: cardCenter.y + grabOffset.vertical))
        home.length = 0
        home.damping = 0.5
        home.frequency = 2.5
        animator.addBehavior(home)
        holdBehavior = home

        frontCard.setStamp(0)
        UIView.animate(withDuration: 0.4) { self.backCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }
    }

    /// Reduce Motion: no physics, the card just slides with the finger.
    private func pannedWithoutPhysics(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: cardArea)
        let width = cardArea.bounds.width
        switch gesture.state {
        case .changed:
            frontCard.transform = CGAffineTransform(translationX: translation.x, y: 0)
            frontCard.setStamp(max(-1, min(translation.x / (width * 0.5), 1)))
        case .ended, .cancelled:
            if translation.x > width * 0.28 {
                fling(.keep, velocity: .zero)
            } else if translation.x < -width * 0.28 {
                fling(.bin, velocity: .zero)
            } else {
                frontCard.transform = .identity
                frontCard.setStamp(0)
            }
        default:
            break
        }
    }

    private func decide(_ decision: SortDecision) {
        fling(decision, velocity: .zero)
    }

    // MARK: Cards

    private func configure(_ card: SortCardView, with item: ViewerItem, position: String?) {
        card.configure(item, position: position,
                       loader: { [presenter] id, size, done in presenter!.loadImage(id: id, targetSize: size, completion: done) },
                       cancel: { [presenter] token in presenter?.cancelImage(token) })
    }

    private func offscreen(_ decision: SortDecision) -> CGAffineTransform {
        let direction: CGFloat = decision == .keep ? 1 : -1
        return CGAffineTransform(translationX: direction * view.bounds.width * 1.2, y: -30).rotated(by: direction * 0.3)
    }
}

// MARK: - SwipeSortViewProtocol

extension SwipeSortViewController: SwipeSortViewProtocol {

    func show(front: ViewerItem, back: ViewerItem?, position: String, canUndo: Bool, transition: SortTransition) {
        summaryView.isHidden = true
        cardArea.isHidden = false
        [binButton, keepButton, closeButton].forEach { $0.isHidden = false }
        positionLabel.text = position
        undoButton.isEnabled = canUndo
        undoButton.alpha = canUndo ? 1 : 0.4
        UIAccessibility.post(notification: .layoutChanged, argument: nil)

        animator.removeAllBehaviors()
        place(frontCard)
        place(backCard)

        switch transition {
        case .none:
            frontCard.alpha = 1
            frontCard.transform = .identity
            configure(frontCard, with: front, position: position)
            backCard.alpha = back == nil ? 0 : 1
            backCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            if let back { configure(backCard, with: back, position: nil) }

        case .forward:
            // The back card is already in place, so it simply becomes the front card
            swap(&frontCard, &backCard)
            cardArea.bringSubviewToFront(frontCard)
            frontCard.alpha = 1
            frontCard.transform = .identity
            frontCard.setStamp(0)
            frontCard.accessibilityLabel = (frontCard.accessibilityLabel ?? "") + ", \(position)"
            backCard.alpha = back == nil ? 0 : 1
            backCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            if let back { configure(backCard, with: back, position: nil) }

        case .undo(let decision):
            // The card that was swiped away flies back in from the side it left
            swap(&frontCard, &backCard)
            configure(frontCard, with: front, position: position)
            frontCard.alpha = reduceMotion ? 0 : 1
            frontCard.transform = reduceMotion ? .identity : offscreen(decision)
            cardArea.bringSubviewToFront(frontCard)
            backCard.alpha = back == nil ? 0 : 1
            if let back { configure(backCard, with: back, position: nil) }
            UIView.animate(withDuration: reduceMotion ? 0.15 : 0.5, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
                self.frontCard.transform = .identity
                self.frontCard.alpha = 1
                self.backCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            }
        }
    }

    func show(summary: SortSummary) {
        cardArea.isHidden = true
        [binButton, keepButton].forEach { $0.isHidden = true }
        undoButton.isEnabled = true
        undoButton.alpha = 1
        positionLabel.text = nil
        summaryView.isHidden = false

        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        summaryTitle.text = summary.remaining == 0 ? "All sorted!" : "Taking a break?"
        let parts = ["Kept \(summary.kept)", "Bin pile \(summary.toBin)"] + (summary.remaining > 0 ? ["\(summary.remaining) still to sort"] : [])
        summaryDetail.text = parts.joined(separator: "  ·  ")

        summaryStack.addArrangedSubview(summaryTitle)
        summaryStack.addArrangedSubview(summaryDetail)
        summaryStack.setCustomSpacing(26, after: summaryDetail)
        if summary.toBin > 0 {
            summaryStack.addArrangedSubview(summaryButton("Bin \(summary.toBin) photo\(summary.toBin == 1 ? "" : "s")", symbol: "trash.fill", filled: true) { [weak self] in
                self?.presenter.didTapBinPending()
            })
        }
        summaryStack.addArrangedSubview(summaryButton(summary.toBin > 0 ? "Close without binning" : "Done", symbol: nil, filled: false) { [weak self] in
            self?.presenter.didTapFinish()
        })
        UIAccessibility.post(notification: .screenChanged, argument: summaryTitle)
    }

    func showCelebration(text: String) {
        CelebrationOverlay.show(text: text, in: view, bottomInset: 90)
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDynamicAnimatorDelegate

extension SwipeSortViewController: UIDynamicAnimatorDelegate {
    /// WHIMSY STEP 6: the engine calls this when everything has come to rest (the wobble has finished).
    /// The tiny leftover tilt is removed so the card sits perfectly straight again.
    func dynamicAnimatorDidPause(_ animator: UIDynamicAnimator) {
        guard !isDragging, !isAnimating else { return }
        animator.removeAllBehaviors()
        place(frontCard)
        frontCard.setStamp(0)
    }
}
