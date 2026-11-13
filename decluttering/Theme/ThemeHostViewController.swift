import UIKit

/// Owns the app's screens so they can be rebuilt in a new theme without losing the theme picker that is open on top.
final class ThemeHostViewController: UIViewController {

    private var content: UIViewController

    init() {
        content = OnThisDayRouter.makeModule()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var childForStatusBarStyle: UIViewController? { content }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BoothTheme.background
        embed(content)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged),
                                               name: ThemeStore.didChange, object: nil)
    }

    private func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    @objc private func themeChanged() {
        let old = content
        let next = OnThisDayRouter.makeModule()
        content = next
        view.backgroundColor = BoothTheme.background

        addChild(next)
        next.view.frame = view.bounds
        next.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let finish: (Bool) -> Void = { [weak self] _ in
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
            next.didMove(toParent: self)
            self?.setNeedsStatusBarAppearanceUpdate()
        }
        if UIAccessibility.isReduceMotionEnabled {
            view.addSubview(next.view)
            finish(true)
        } else {
            transition(from: old, to: next, duration: 0.3, options: .transitionCrossDissolve, animations: nil, completion: finish)
        }
    }
}
