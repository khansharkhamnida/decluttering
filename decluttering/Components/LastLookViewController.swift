import UIKit

typealias ThumbnailLoader = (_ id: String, _ targetSize: CGSize, _ completion: @escaping (UIImage?) -> Void) -> ThumbnailToken?

/// "Are you sure you really need these?" A gentle last look before anything is binned.
final class LastLookViewController: UIViewController {

    private let ids: [String]
    private let loader: ThumbnailLoader
    private let onConfirm: () -> Void

    private let fan = UIView()
    private var fanFrames: [UIView] = []

    init(ids: [String], loader: @escaping ThumbnailLoader, onConfirm: @escaping () -> Void) {
        self.ids = ids
        self.loader = loader
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(from host: UIViewController, ids: [String], loader: @escaping ThumbnailLoader, onConfirm: @escaping () -> Void) {
        let controller = LastLookViewController(ids: ids, loader: loader, onConfirm: onConfirm)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        host.present(controller, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = BoothTheme.sheetStyle
        view.backgroundColor = BoothTheme.surface
        buildFan()

        let question = UILabel()
        question.text = BoothVoice.lastLookQuestion()
        question.font = BoothTheme.font(24, .heavy)
        question.textColor = BoothTheme.ink
        question.numberOfLines = 0
        question.textAlignment = .center

        let photos = ids.count == 1 ? "this photo" : "these \(ids.count) photos"
        let note = UILabel()
        note.text = "Binning \(photos). They wait in Recently Deleted for up to 30 days, so nothing is lost forever."
        note.font = BoothTheme.font(14, .semibold)
        note.textColor = BoothTheme.ink.withAlphaComponent(0.75)
        note.numberOfLines = 0
        note.textAlignment = .center

        var confirmConfig = UIButton.Configuration.filled()
        confirmConfig.title = "Yes, bin them"
        confirmConfig.image = UIImage(systemName: "trash.fill")
        confirmConfig.imagePadding = 8
        confirmConfig.baseBackgroundColor = BoothTheme.ink
        confirmConfig.baseForegroundColor = BoothTheme.paper
        confirmConfig.cornerStyle = .capsule
        confirmConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        confirmConfig.attributedTitle = AttributedString("Yes, bin them", attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        let confirm = UIButton(configuration: confirmConfig)
        confirm.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let action = self.onConfirm
            self.dismiss(animated: true) { action() }
        }, for: .touchUpInside)

        var keepConfig = UIButton.Configuration.plain()
        keepConfig.baseForegroundColor = BoothTheme.ink
        keepConfig.attributedTitle = AttributedString("Hmm, not yet", attributes: AttributeContainer([.font: BoothTheme.font(16, .bold)]))
        let keep = UIButton(configuration: keepConfig)
        keep.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [fan, question, note, confirm, keep])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(18, after: fan)
        stack.setCustomSpacing(20, after: note)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            fan.heightAnchor.constraint(equalToConstant: 130),
            fan.widthAnchor.constraint(equalToConstant: 250)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // The photos wobble once, as if Binny is holding them up for a look
        for (index, frame) in fanFrames.enumerated() {
            let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let base = frame.layer.value(forKeyPath: "transform.rotation.z") as? CGFloat ?? 0
            wobble.values = [base, base - 0.08, base + 0.08, base]
            wobble.duration = 0.6
            wobble.beginTime = CACurrentMediaTime() + Double(index) * 0.08
            wobble.fillMode = .backwards
            frame.layer.add(wobble, forKey: "wobble")
        }
    }

    private func buildFan() {
        let shown = Array(ids.prefix(3))
        let angles: [CGFloat] = shown.count == 1 ? [0] : (shown.count == 2 ? [-0.14, 0.14] : [-0.2, 0, 0.2])
        let offsets: [CGFloat] = shown.count == 1 ? [0] : (shown.count == 2 ? [-46, 46] : [-80, 0, 80])
        let side: CGFloat = shown.count == 1 ? 120 : 104

        for (index, id) in shown.enumerated() {
            let frame = UIView()
            frame.backgroundColor = .white
            frame.layer.cornerRadius = 6
            frame.layer.shadowColor = UIColor.black.cgColor
            frame.layer.shadowOpacity = 0.25
            frame.layer.shadowRadius = 6
            frame.layer.shadowOffset = CGSize(width: 0, height: 3)
            frame.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 3
            imageView.backgroundColor = BoothTheme.folderBack
            imageView.translatesAutoresizingMaskIntoConstraints = false
            frame.addSubview(imageView)
            fan.addSubview(frame)

            NSLayoutConstraint.activate([
                frame.widthAnchor.constraint(equalToConstant: side),
                frame.heightAnchor.constraint(equalToConstant: side + 14),
                frame.centerXAnchor.constraint(equalTo: fan.centerXAnchor, constant: offsets[index]),
                frame.centerYAnchor.constraint(equalTo: fan.centerYAnchor),
                imageView.topAnchor.constraint(equalTo: frame.topAnchor, constant: 6),
                imageView.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 6),
                imageView.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -6),
                imageView.heightAnchor.constraint(equalTo: frame.widthAnchor, constant: -12)
            ])
            frame.transform = CGAffineTransform(rotationAngle: angles[index])
            fanFrames.append(frame)

            let pixels = side * traitCollection.displayScale * 1.5
            _ = loader(id, CGSize(width: pixels, height: pixels)) { [weak imageView] image in
                if let image { imageView?.image = image }
            }
        }
    }
}
