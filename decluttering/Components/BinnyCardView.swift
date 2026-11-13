import UIKit

/// Binny: a smiling little bin who blinks, bobs and says things.
final class BinnyView: UIView {

    private let bob = CALayer()
    private let leftEye = CAShapeLayer()
    private let rightEye = CAShapeLayer()

    override var intrinsicContentSize: CGSize { CGSize(width: 64, height: 72) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        bob.frame = CGRect(x: 0, y: 0, width: 64, height: 72)
        layer.addSublayer(bob)
        drawBinny()
        startIdleAnimations()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func shape(_ path: UIBezierPath, fill: UIColor?, stroke: UIColor? = nil, width: CGFloat = 0) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.fillColor = fill?.cgColor
        layer.strokeColor = stroke?.cgColor
        layer.lineWidth = width
        layer.lineCap = .round
        return layer
    }

    private func photo(_ rect: CGRect, color: UIColor, angle: CGFloat) -> CAShapeLayer {
        let layer = shape(UIBezierPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerRadius: 3), fill: color)
        layer.bounds = CGRect(origin: .zero, size: rect.size)
        layer.position = CGPoint(x: rect.midX, y: rect.midY)
        layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        return layer
    }

    private func drawBinny() {
        // Photos peeking out of the top
        bob.addSublayer(photo(CGRect(x: 10, y: 1, width: 22, height: 20), color: UIColor(hex: 0xF4A58A), angle: -0.22))
        bob.addSublayer(photo(CGRect(x: 30, y: 3, width: 22, height: 20), color: UIColor(hex: 0xB9A5F0), angle: 0.2))

        let cream = BoothTheme.binBody
        let blush = UIColor(hex: 0xF2CFC6)

        let body = UIBezierPath()
        body.move(to: CGPoint(x: 10, y: 24))
        body.addLine(to: CGPoint(x: 54, y: 24))
        body.addLine(to: CGPoint(x: 50, y: 62))
        body.addQuadCurve(to: CGPoint(x: 46, y: 67), controlPoint: CGPoint(x: 49.5, y: 67))
        body.addLine(to: CGPoint(x: 18, y: 67))
        body.addQuadCurve(to: CGPoint(x: 14, y: 62), controlPoint: CGPoint(x: 14.5, y: 67))
        body.close()
        bob.addSublayer(shape(body, fill: cream))

        for x in [22.0, 32.0, 42.0] {
            let ridge = UIBezierPath()
            ridge.move(to: CGPoint(x: x, y: 31))
            ridge.addLine(to: CGPoint(x: x - (x - 32) * 0.1, y: 60))
            bob.addSublayer(shape(ridge, fill: nil, stroke: blush, width: 2))
        }

        bob.addSublayer(shape(UIBezierPath(roundedRect: CGRect(x: 24, y: 9, width: 16, height: 8), cornerRadius: 4), fill: cream))
        bob.addSublayer(shape(UIBezierPath(roundedRect: CGRect(x: 6, y: 16, width: 52, height: 9), cornerRadius: 4.5), fill: cream))

        // Face
        for (eye, center) in [(leftEye, CGPoint(x: 25, y: 43)), (rightEye, CGPoint(x: 39, y: 43))] {
            eye.bounds = CGRect(x: 0, y: 0, width: 5, height: 6)
            eye.position = center
            eye.path = UIBezierPath(ovalIn: eye.bounds).cgPath
            eye.fillColor = BoothTheme.binFace.cgColor
            bob.addSublayer(eye)
        }
        let smile = UIBezierPath(arcCenter: CGPoint(x: 32, y: 47), radius: 5, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: true)
        bob.addSublayer(shape(smile, fill: nil, stroke: BoothTheme.binFace, width: 2))
        for x in [16.0, 42.0] {
            bob.addSublayer(shape(UIBezierPath(ovalIn: CGRect(x: x, y: 47, width: 6, height: 4)), fill: UIColor(hex: 0xF4A5A8).withAlphaComponent(0.8)))
        }
    }

    private func startIdleAnimations() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let float = CABasicAnimation(keyPath: "transform.translation.y")
        float.fromValue = 0
        float.toValue = -3
        float.duration = 1.4
        float.autoreverses = true
        float.repeatCount = .infinity
        float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bob.add(float, forKey: "float")

        let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
        blink.values = [1, 1, 0.1, 1, 1]
        blink.keyTimes = [0, 0.9, 0.94, 0.98, 1]
        blink.duration = 3.6
        blink.repeatCount = .infinity
        [leftEye, rightEye].forEach { $0.add(blink, forKey: "blink") }
    }

    func wiggle() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [0, -0.22, 0.22, -0.14, 0.08, 0]
        wiggle.duration = 0.6
        bob.add(wiggle, forKey: "wiggle")
    }

    func hop() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let spring = CASpringAnimation(keyPath: "transform.translation.y")
        spring.fromValue = -16
        spring.toValue = 0
        spring.damping = 6
        spring.stiffness = 180
        spring.duration = spring.settlingDuration
        bob.add(spring, forKey: "hop")
    }
}

/// Binny plus a speech bubble. Tap Binny for another quote.
final class BinnyCardView: UIView {

    var onTap: (() -> Void)?

    private let binny = BinnyView()
    private let bubble = UIView()
    private let tail = UIView()
    private let quoteLabel = UILabel()
    private let statsLabel = UILabel()
    private var typingTask: Task<Void, Never>?
    private var spokenQuote = ""
    private var spokenStats = ""
    private var revealedCount = 0
    private var bubbleHeight: NSLayoutConstraint!
    private var quoteHeight: NSLayoutConstraint!

    private static let bubbleBaseHeight: CGFloat = 96
    private static let bubbleMaxHeight: CGFloat = 150

    override init(frame: CGRect) {
        super.init(frame: frame)

        quoteLabel.numberOfLines = 2
        quoteLabel.lineBreakMode = .byTruncatingTail
        quoteLabel.adjustsFontSizeToFitWidth = true
        quoteLabel.minimumScaleFactor = 0.75
        statsLabel.numberOfLines = 1
        statsLabel.lineBreakMode = .byTruncatingTail
        statsLabel.adjustsFontSizeToFitWidth = true
        statsLabel.minimumScaleFactor = 0.75
        statsLabel.font = BoothTheme.font(11, .bold, maxScale: 1.4)
        statsLabel.textColor = BoothTheme.ink.withAlphaComponent(0.65)

        bubble.backgroundColor = BoothTheme.paper
        bubble.layer.cornerRadius = 16
        tail.backgroundColor = BoothTheme.paper
        tail.layer.cornerRadius = 2

        let texts = UIStackView(arrangedSubviews: [quoteLabel, statsLabel])
        texts.axis = .vertical
        texts.spacing = 5

        bubbleHeight = bubble.heightAnchor.constraint(equalToConstant: Self.bubbleBaseHeight)
        quoteHeight = quoteLabel.heightAnchor.constraint(equalToConstant: 34)

        [tail, bubble, binny, texts].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(tail)
        addSubview(bubble)
        addSubview(binny)
        bubble.addSubview(texts)

        NSLayoutConstraint.activate([
            binny.leadingAnchor.constraint(equalTo: leadingAnchor),
            binny.centerYAnchor.constraint(equalTo: centerYAnchor),
            binny.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            binny.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            bubble.leadingAnchor.constraint(equalTo: binny.trailingAnchor, constant: 10),
            bubble.trailingAnchor.constraint(equalTo: trailingAnchor),
            bubble.topAnchor.constraint(equalTo: topAnchor),
            bubble.bottomAnchor.constraint(equalTo: bottomAnchor),
            bubbleHeight,

            tail.widthAnchor.constraint(equalToConstant: 12),
            tail.heightAnchor.constraint(equalToConstant: 12),
            tail.centerXAnchor.constraint(equalTo: bubble.leadingAnchor),
            tail.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),

            texts.centerYAnchor.constraint(equalTo: bubble.centerYAnchor),
            quoteHeight,
            texts.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            texts.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14)
        ])
        tail.transform = CGAffineTransform(rotationAngle: .pi / 4)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Shows another quote"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))

        updateMetrics()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: BinnyCardView, _) in
            self.updateMetrics()
            self.quoteLabel.attributedText = self.styled(self.spokenQuote, revealed: self.revealedCount)
        }
    }

    /// One deterministic bubble size per text size, whatever Binny says.
    private func updateMetrics() {
        bubbleHeight.constant = min(UIFontMetrics.default.scaledValue(for: Self.bubbleBaseHeight), Self.bubbleMaxHeight)
        quoteHeight.constant = ceil(BoothTheme.font(14, .semibold).lineHeight * 2)
        statsLabel.font = BoothTheme.font(11, .bold, maxScale: 1.4)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        binny.wiggle()
        BoothHaptics.shared.tap()
        onTap?()
    }

    func celebrate() { binny.hop() }

    func say(_ text: String, animated: Bool = true) {
        typingTask?.cancel()
        spokenQuote = text
        updateSpokenLabel()
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            revealedCount = text.count
            quoteLabel.attributedText = styled(text, revealed: text.count)
            return
        }
        // The full text is laid out from the start, so the bubble never jumps while it "types"
        typingTask = Task { [weak self] in
            for count in 0...text.count {
                guard !Task.isCancelled, let self else { return }
                self.revealedCount = count
                self.quoteLabel.attributedText = self.styled(text, revealed: count)
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func setStats(_ stats: BoothStats) {
        let text = NSMutableAttributedString()
        if stats.binned == 0 && stats.kept == 0 {
            text.append(NSAttributedString(string: "Your first bin starts a streak"))
        } else {
            let flame = NSTextAttachment(image: UIImage(systemName: "flame.fill")?.withTintColor(BoothTheme.ink.withAlphaComponent(0.65)) ?? UIImage())
            text.append(NSAttributedString(attachment: flame))
            text.append(NSAttributedString(string: " \(stats.streak)-day streak  ·  \(stats.binned) binned  ·  \(stats.kept) kept"))
        }
        statsLabel.attributedText = text
        statsLabel.font = BoothTheme.font(11, .bold, maxScale: 1.4)
        spokenStats = stats.binned == 0 && stats.kept == 0
            ? "Your first bin starts a streak"
            : "\(stats.streak) day streak, \(stats.binned) binned, \(stats.kept) kept"
        updateSpokenLabel()
    }

    private func updateSpokenLabel() {
        accessibilityLabel = [spokenQuote, spokenStats].filter { !$0.isEmpty }.joined(separator: ". ")
    }

    private func styled(_ text: String, revealed: Int) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: BoothTheme.font(14, .semibold),
            .foregroundColor: BoothTheme.ink
        ])
        if revealed < text.count {
            result.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: revealed, length: text.count - revealed))
        }
        return result
    }
}
