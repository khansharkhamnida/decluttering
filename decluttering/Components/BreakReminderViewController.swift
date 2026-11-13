import UIKit

/// "Time for a little break?" Shown once at each level, and never blocks anyone from carrying on.
final class BreakReminderViewController: UIViewController {

    private let level: BreakLevel
    private let count: Int
    private let onBreak: () -> Void

    init(level: BreakLevel, count: Int, onBreak: @escaping () -> Void) {
        self.level = level
        self.count = count
        self.onBreak = onBreak
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func present(from host: UIViewController, level: BreakLevel, count: Int, onBreak: @escaping () -> Void) {
        // Present from whatever is on top, so it also works over the photo viewer or swipe sort
        var top = host
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        guard !(top is BreakReminderViewController) else { return }

        let controller = BreakReminderViewController(level: level, count: count, onBreak: onBreak)
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        top.present(controller, animated: true)
        BoothHaptics.shared.sparkle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = BoothTheme.sheetStyle
        view.backgroundColor = BoothTheme.surface
        let copy = BoothVoice.breakCopy(level: level, count: count)

        let binny = BinnyView()

        let title = UILabel()
        title.text = copy.title
        title.font = BoothTheme.font(26, .heavy)
        title.textColor = BoothTheme.ink
        title.textAlignment = .center
        title.numberOfLines = 0

        let body = UILabel()
        body.text = copy.body
        body.font = BoothTheme.font(16, .semibold)
        body.textColor = BoothTheme.ink.withAlphaComponent(0.8)
        body.textAlignment = .center
        body.numberOfLines = 0

        var primaryConfig = UIButton.Configuration.filled()
        primaryConfig.image = UIImage(systemName: "cup.and.saucer.fill")
        primaryConfig.imagePadding = 8
        primaryConfig.baseBackgroundColor = BoothTheme.ink
        primaryConfig.baseForegroundColor = BoothTheme.paper
        primaryConfig.cornerStyle = .capsule
        primaryConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 28, bottom: 14, trailing: 28)
        primaryConfig.attributedTitle = AttributedString(copy.primary, attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        let primary = UIButton(configuration: primaryConfig)
        primary.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let action = self.onBreak
            self.dismiss(animated: true) { action() }
        }, for: .touchUpInside)

        var secondaryConfig = UIButton.Configuration.plain()
        secondaryConfig.baseForegroundColor = BoothTheme.ink
        secondaryConfig.attributedTitle = AttributedString(copy.secondary, attributes: AttributeContainer([.font: BoothTheme.font(16, .bold)]))
        let secondary = UIButton(configuration: secondaryConfig)
        secondary.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [binny, title, body, primary, secondary])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(18, after: binny)
        stack.setCustomSpacing(22, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -28)
        ])
    }
}
