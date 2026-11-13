import UIKit

/// A burst of paper confetti and a little message, shown after binning or keeping.
enum CelebrationOverlay {

    /// `bottomInset` is the gap between the toast and the bottom safe area, so it can clear any buttons.
    static func show(text: String, in host: UIView, bottomInset: CGFloat = 96) {
        BoothHaptics.shared.crumple()
        UIAccessibility.post(notification: .announcement, argument: text)
        if !UIAccessibility.isReduceMotionEnabled { burstConfetti(in: host) }
        showToast(text, in: host, bottomInset: bottomInset)
    }

    private static func burstConfetti(in host: UIView) {
        let emitter = CAEmitterLayer()
        emitter.frame = host.bounds
        emitter.emitterPosition = CGPoint(x: host.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: host.bounds.width, height: 1)
        emitter.zPosition = 10

        let colors: [UIColor] = [BoothTheme.paper, BoothTheme.accent, UIColor(hex: 0xF4A5A8), UIColor(hex: 0xB9A5F0), UIColor(hex: 0xF4A58A)]
        emitter.emitterCells = colors.flatMap { color in
            [CGSize(width: 8, height: 12), CGSize(width: 6, height: 6)].map { size -> CAEmitterCell in
                let cell = CAEmitterCell()
                cell.contents = piece(color: color, size: size).cgImage
                cell.birthRate = 7
                cell.lifetime = 3.2
                cell.velocity = 260
                cell.velocityRange = 110
                cell.emissionLongitude = .pi / 2
                cell.emissionRange = .pi / 5
                cell.yAcceleration = 380
                cell.spin = 3
                cell.spinRange = 5
                cell.scale = 1
                cell.scaleRange = 0.4
                cell.alphaSpeed = -0.28
                return cell
            }
        }
        host.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { emitter.removeFromSuperlayer() }
    }

    private static func piece(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
        }
    }

    private static func showToast(_ text: String, in host: UIView, bottomInset: CGFloat) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 2
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.font = BoothTheme.font(15, .bold)
        label.textColor = BoothTheme.paper

        let toast = UIView()
        toast.backgroundColor = BoothTheme.ink
        toast.layer.cornerRadius = 20
        toast.layer.borderColor = BoothTheme.paper.cgColor
        toast.layer.borderWidth = 2.5
        toast.layer.shadowColor = UIColor.black.cgColor
        toast.layer.shadowOpacity = 0.3
        toast.layer.shadowRadius = 8
        toast.layer.shadowOffset = CGSize(width: 0, height: 4)
        toast.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(label)
        host.addSubview(toast)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -18),
            toast.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -bottomInset),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            toast.widthAnchor.constraint(equalToConstant: min(host.bounds.width - 48, 360))
        ])

        let reduce = UIAccessibility.isReduceMotionEnabled
        toast.alpha = 0
        toast.transform = reduce ? .identity : CGAffineTransform(scaleX: 0.7, y: 0.7).translatedBy(x: 0, y: 20)
        UIView.animate(withDuration: reduce ? 0.15 : 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            toast.alpha = 1
            toast.transform = .identity
        }
        UIView.animate(withDuration: 0.4, delay: 2.8, options: []) {
            toast.alpha = 0
        } completion: { _ in toast.removeFromSuperview() }
    }
}
