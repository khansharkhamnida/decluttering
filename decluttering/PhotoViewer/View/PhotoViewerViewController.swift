import AVFoundation
import Photos
import PhotosUI
import UIKit

// MARK: - Video surface

private final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - One page: a zoomable photo, a Live Photo, or a video

final class ViewerPhotoCell: UICollectionViewCell, UIScrollViewDelegate {
    static let reuseID = "ViewerPhotoCell"

    var representedID: String?
    var imageToken: ThumbnailToken?
    var mediaToken: ThumbnailToken?
    var onSingleTap: (() -> Void)?
    var onPlayRequested: (() -> Void)?

    private(set) var kind: MediaKind = .photo

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let liveView = PHLivePhotoView()
    private let playerView = PlayerView()
    private let playButton = UIButton(type: .system)
    private let hint = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bouncesZoom = true
        contentView.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        liveView.contentMode = .scaleAspectFit
        liveView.isHidden = true
        scrollView.addSubview(liveView)
        playerView.playerLayer.videoGravity = .resizeAspect
        playerView.isHidden = true
        scrollView.addSubview(playerView)

        spinner.color = BoothTheme.onViewer
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)

        var playConfig = UIButton.Configuration.filled()
        playConfig.image = UIImage(systemName: "play.fill")
        playConfig.baseBackgroundColor = BoothTheme.paper
        playConfig.baseForegroundColor = BoothTheme.ink
        playConfig.cornerStyle = .capsule
        playConfig.contentInsets = NSDirectionalEdgeInsets(top: 22, leading: 24, bottom: 22, trailing: 24)
        playConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        playButton.configuration = playConfig
        playButton.isHidden = true
        playButton.accessibilityLabel = "Play video"
        playButton.addAction(UIAction { [weak self] _ in self?.togglePlayback() }, for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playButton)

        hint.text = "Hold to play"
        hint.font = BoothTheme.font(13, .bold)
        hint.textColor = BoothTheme.onViewer
        hint.textAlignment = .center
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        hint.layer.cornerRadius = 12
        hint.clipsToBounds = true
        hint.alpha = 0
        hint.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hint)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            hint.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -96),
            hint.widthAnchor.constraint(equalToConstant: 130),
            hint.heightAnchor.constraint(equalToConstant: 26)
        ])

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        // Everything matches the page while not zoomed; zooming scales the content from there
        if scrollView.zoomScale == 1 {
            [imageView, liveView, playerView].forEach { $0.frame = bounds }
            scrollView.contentSize = bounds.size
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPlayback()
        scrollView.setZoomScale(1, animated: false)
        imageView.image = nil
        imageView.isHidden = false
        liveView.livePhoto = nil
        liveView.isHidden = true
        hint.layer.removeAllAnimations()
        hint.alpha = 0
        representedID = nil
        imageToken = nil
        mediaToken = nil
        spinner.startAnimating()
    }

    func configure(kind: MediaKind) {
        self.kind = kind
        scrollView.maximumZoomScale = kind == .video ? 1 : 4
        playButton.isHidden = kind != .video
        accessibilityLabel = kind == .video ? "Video" : (kind == .livePhoto ? "Live Photo" : "Photo")
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        image == nil ? spinner.startAnimating() : spinner.stopAnimating()
    }

    func setLivePhoto(_ livePhoto: PHLivePhoto?) {
        guard let livePhoto else { return }
        liveView.livePhoto = livePhoto
        liveView.isHidden = false
        imageView.isHidden = true
        spinner.stopAnimating()
        showHint()
    }

    func play(_ item: AVPlayerItem?) {
        guard let item else { return }
        let player = AVPlayer(playerItem: item)
        self.player = player
        playerView.playerLayer.player = player
        playerView.isHidden = false
        playButton.isHidden = true
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            // Back to the start, ready to play again
            self?.player?.seek(to: .zero)
            self?.player?.pause()
            self?.playButton.isHidden = false
        }
        player.play()
    }

    func stopPlayback() {
        player?.pause()
        player = nil
        playerView.playerLayer.player = nil
        playerView.isHidden = true
        playButton.isHidden = kind != .video
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        liveView.livePhoto != nil ? liveView : imageView
    }

    private func togglePlayback() {
        guard let player else { return onPlayRequested?() ?? () }
        if player.timeControlStatus == .paused {
            player.play()
            playButton.isHidden = true
        } else {
            player.pause()
            playButton.isHidden = false
        }
    }

    private func showHint() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.3) { self.hint.alpha = 1 }
        UIView.animate(withDuration: 0.4, delay: 2.5) { self.hint.alpha = 0 }
    }

    @objc private func singleTapped() {
        if kind == .video { togglePlayback() } else { onSingleTap?() }
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        guard kind != .video else { return }
        guard scrollView.zoomScale == 1 else { return scrollView.setZoomScale(1, animated: true) }
        let point = gesture.location(in: liveView.livePhoto != nil ? liveView : imageView)
        let scale: CGFloat = 2.5
        let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
        scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                   width: size.width, height: size.height), animated: true)
    }
}

// MARK: - Gradient behind the controls

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    init(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint) {
        super.init(frame: .zero)
        let gradient = layer as! CAGradientLayer
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = startPoint
        gradient.endPoint = endPoint
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Viewer

final class PhotoViewerViewController: UIViewController {

    var presenter: PhotoViewerPresenterProtocol!

    /// Read by the zoom transition to find the thumbnail to shrink back into.
    private(set) var currentID: String?

    private var items: [ViewerItem] = []
    private var currentIndex = 0
    private var hasScrolledToStart = false
    private var chromeHidden = false

    private let layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(ViewerPhotoCell.self, forCellWithReuseIdentifier: ViewerPhotoCell.reuseID)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.contentInsetAdjustmentBehavior = .never
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let topShade = GradientView(colors: [UIColor.black.withAlphaComponent(0.6), .clear],
                                        startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1))
    private let bottomShade = GradientView(colors: [.clear, UIColor.black.withAlphaComponent(0.6)],
                                           startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1))
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let counterLabel = UILabel()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark")
        config.baseBackgroundColor = BoothTheme.paper
        config.baseForegroundColor = BoothTheme.ink
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        let button = UIButton(configuration: config)
        button.accessibilityLabel = "Close"
        button.addAction(UIAction { [weak self] _ in self?.presenter.didTapClose() }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var keepButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "heart.fill")
        config.imagePadding = 8
        config.attributedTitle = AttributedString("Keep", attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        config.baseBackgroundColor = BoothTheme.paper
        config.baseForegroundColor = BoothTheme.ink
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 26, bottom: 14, trailing: 26)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.presenter.didTapKeep() }, for: .touchUpInside)
        return button
    }()

    private lazy var actionStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [keepButton, binButton])
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var binButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "trash.fill")
        config.imagePadding = 8
        config.attributedTitle = AttributedString("Bin it", attributes: AttributeContainer([.font: BoothTheme.font(17, .heavy)]))
        config.baseBackgroundColor = BoothTheme.ink
        config.baseForegroundColor = BoothTheme.paper
        config.background.strokeColor = BoothTheme.paper
        config.background.strokeWidth = 3
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 26, bottom: 14, trailing: 26)
        let button = UIButton(configuration: config)
        button.addAction(UIAction { [weak self] _ in self?.presenter.didTapBin() }, for: .touchUpInside)
        return button
    }()

    override var prefersStatusBarHidden: Bool { chromeHidden }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = BoothTheme.viewerBackground
        setUpLayout()
        presenter.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = collectionView.bounds.size
        guard size.width > 0 else { return }

        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
            collectionView.setContentOffset(CGPoint(x: CGFloat(currentIndex) * size.width, y: 0), animated: false)
        }
        if !hasScrolledToStart, !items.isEmpty {
            hasScrolledToStart = true
            collectionView.setContentOffset(CGPoint(x: CGFloat(currentIndex) * size.width, y: 0), animated: false)
        }
    }

    // MARK: Setup

    private func setUpLayout() {
        titleLabel.font = BoothTheme.font(17, .heavy, maxScale: 1.2)
        titleLabel.textColor = BoothTheme.onViewer
        subtitleLabel.font = BoothTheme.font(13, .semibold, maxScale: 1.2)
        subtitleLabel.textColor = BoothTheme.viewerAccent
        counterLabel.font = BoothTheme.font(13, .semibold, maxScale: 1.2)
        counterLabel.textColor = BoothTheme.onViewer
        counterLabel.textAlignment = .right

        let titles = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titles.axis = .vertical
        titles.alignment = .center
        titles.translatesAutoresizingMaskIntoConstraints = false
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        [closeButton, titles, counterLabel].forEach { topBar.addSubview($0) }

        [topShade, bottomShade].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        [collectionView, topShade, bottomShade, topBar, actionStack].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 56),
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titles.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titles.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            counterLabel.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -20),
            counterLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            counterLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titles.trailingAnchor, constant: 8),

            topShade.topAnchor.constraint(equalTo: view.topAnchor),
            topShade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topShade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topShade.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 16),

            actionStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bottomShade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomShade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomShade.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomShade.topAnchor.constraint(equalTo: actionStack.topAnchor, constant: -40)
        ])
    }

    // MARK: Controls

    private func toggleChrome() {
        chromeHidden.toggle()
        let alpha: CGFloat = chromeHidden ? 0 : 1
        UIView.animate(withDuration: 0.2) {
            [self.topBar, self.topShade, self.actionStack, self.bottomShade].forEach { $0.alpha = alpha }
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    private func pixelSize() -> CGSize {
        // A little over screen size, so a zoomed photo stays reasonably sharp
        let scale = view.traitCollection.displayScale * 1.5
        return CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
    }
}

// MARK: - PhotoViewerViewProtocol

extension PhotoViewerViewController: PhotoViewerViewProtocol {

    func show(items: [ViewerItem], index: Int) {
        self.items = items
        currentIndex = index
        currentID = items.indices.contains(index) ? items[index].id : nil
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        if collectionView.bounds.width > 0 {
            collectionView.setContentOffset(CGPoint(x: CGFloat(index) * collectionView.bounds.width, y: 0), animated: false)
        }
    }

    func showHeader(title: String, subtitle: String, counter: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        counterLabel.text = counter
    }

    func showCelebration(text: String) {
        CelebrationOverlay.show(text: text, in: view, bottomInset: 92)
    }

    func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension PhotoViewerViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewerPhotoCell.reuseID, for: indexPath) as! ViewerPhotoCell
        let item = items[indexPath.item]
        let id = item.id
        cell.representedID = id
        cell.configure(kind: item.kind)
        cell.onSingleTap = { [weak self] in self?.toggleChrome() }
        cell.setImage(nil)
        cell.imageToken = presenter.loadImage(id: id, targetSize: pixelSize()) { [weak cell] image in
            guard let cell, cell.representedID == id, let image else { return }
            cell.setImage(image)
        }
        switch item.kind {
        case .livePhoto:
            cell.mediaToken = presenter.loadLivePhoto(id: id, targetSize: pixelSize()) { [weak cell] live in
                guard let cell, cell.representedID == id else { return }
                cell.setLivePhoto(live)
            }
        case .video:
            cell.onPlayRequested = { [weak self, weak cell] in
                guard let self, let cell else { return }
                cell.mediaToken = self.presenter.loadPlayerItem(id: id) { [weak cell] playerItem in
                    guard let cell, cell.representedID == id else { return }
                    cell.play(playerItem)
                }
            }
        case .photo:
            break
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension PhotoViewerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ViewerPhotoCell else { return }
        if let token = cell.imageToken { presenter.cancelImage(token) }
        if let token = cell.mediaToken { presenter.cancelImage(token) }
        cell.imageToken = nil
        cell.mediaToken = nil
        cell.stopPlayback()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.bounds.width
        guard width > 0, !items.isEmpty else { return }
        let index = min(max(Int((scrollView.contentOffset.x + width / 2) / width), 0), items.count - 1)
        guard index != currentIndex else { return }
        currentIndex = index
        currentID = items[index].id
        presenter.didChangePage(to: index)
    }
}
