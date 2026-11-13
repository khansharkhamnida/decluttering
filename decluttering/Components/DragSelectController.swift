import UIKit

/// Photos-style drag-to-select: long-press a photo, then drag across others without lifting.
final class DragSelectController: NSObject {

    private enum Metrics {
        static let edgeZone: CGFloat = 90
        static let maxScrollSpeed: CGFloat = 1100   // points per second at the very edge
    }

    private weak var collectionView: UICollectionView?
    private let isSelecting: () -> Bool
    private let isSelected: (IndexPath) -> Bool
    private let beginSelecting: () -> Void
    private let apply: (IndexPath, Bool) -> Void

    private let recognizer = UILongPressGestureRecognizer()
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let tick = UISelectionFeedbackGenerator()
    private var displayLink: CADisplayLink?
    private var selectMode = true
    private var lastPath: IndexPath?
    private var isDragging = false

    init(collectionView: UICollectionView,
         isSelecting: @escaping () -> Bool,
         isSelected: @escaping (IndexPath) -> Bool,
         beginSelecting: @escaping () -> Void,
         apply: @escaping (IndexPath, Bool) -> Void) {
        self.collectionView = collectionView
        self.isSelecting = isSelecting
        self.isSelected = isSelected
        self.beginSelecting = beginSelecting
        self.apply = apply
        super.init()
        recognizer.minimumPressDuration = 0.35
        recognizer.allowableMovement = 1000   // the finger keeps moving after the press
        recognizer.addTarget(self, action: #selector(handle(_:)))
        collectionView.addGestureRecognizer(recognizer)
    }

    deinit {
        displayLink?.invalidate()
        collectionView?.removeGestureRecognizer(recognizer)
    }

    // MARK: Pure logic

    /// Index paths from `from` to `to` inclusive, in grid order (section, then item).
    /// Runs backwards when `to` precedes `from`. Empty or collapsed sections are skipped.
    static func indexPaths(from: IndexPath, to: IndexPath, itemCounts: [Int]) -> [IndexPath] {
        func linear(_ path: IndexPath) -> Int? {
            guard itemCounts.indices.contains(path.section),
                  path.item >= 0, path.item < itemCounts[path.section] else { return nil }
            return itemCounts[..<path.section].reduce(0, +) + path.item
        }
        guard let start = linear(from), let end = linear(to) else { return [] }

        var all: [IndexPath] = []
        for (section, count) in itemCounts.enumerated() {
            all.append(contentsOf: (0..<count).map { IndexPath(item: $0, section: section) })
        }
        let slice = all[min(start, end)...max(start, end)]
        return start <= end ? Array(slice) : slice.reversed()
    }

    // MARK: Gesture

    @objc private func handle(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began: began(gesture)
        case .changed: if isDragging { moved(gesture) }
        case .ended, .cancelled, .failed: finish()
        default: break
        }
    }

    private func began(_ gesture: UILongPressGestureRecognizer) {
        guard let collectionView,
              var path = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
            cancel(gesture)   // header or gap: no side effects
            return
        }

        if isSelecting() {
            selectMode = !isSelected(path)
        } else {
            beginSelecting()
            collectionView.layoutIfNeeded()   // folders reopen, so the photo under the finger has moved
            selectMode = true
            guard let resolved = collectionView.indexPathForItem(at: gesture.location(in: collectionView)) else {
                cancel(gesture)
                return
            }
            path = resolved
        }

        isDragging = true
        collectionView.isScrollEnabled = false
        impact.impactOccurred()
        tick.prepare()
        apply(path, selectMode)
        lastPath = path
        startAutoScroll()
    }

    private func cancel(_ gesture: UILongPressGestureRecognizer) {
        gesture.isEnabled = false
        gesture.isEnabled = true
    }

    private func moved(_ gesture: UILongPressGestureRecognizer) {
        guard let collectionView,
              let path = collectionView.indexPathForItem(at: gesture.location(in: collectionView)),
              path != lastPath else { return }

        if let last = lastPath {
            let counts = (0..<collectionView.numberOfSections).map { collectionView.numberOfItems(inSection: $0) }
            for between in Self.indexPaths(from: last, to: path, itemCounts: counts) where isSelected(between) != selectMode {
                apply(between, selectMode)
                tick.selectionChanged()
            }
        }
        lastPath = path
    }

    private func finish() {
        guard isDragging else { return }
        isDragging = false
        lastPath = nil
        stopAutoScroll()
        collectionView?.isScrollEnabled = true
    }

    // MARK: Auto-scroll

    private func startAutoScroll() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(autoScrollStep(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAutoScroll() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func autoScrollStep(_ link: CADisplayLink) {
        guard let collectionView, isDragging else { return stopAutoScroll() }

        let viewportY = recognizer.location(in: collectionView).y - collectionView.contentOffset.y
        let top = collectionView.safeAreaInsets.top
        let bottom = collectionView.bounds.height - collectionView.safeAreaInsets.bottom
        let zone = Metrics.edgeZone

        var direction: CGFloat = 0
        var proximity: CGFloat = 0
        if viewportY < top + zone {
            direction = -1
            proximity = min(1, (top + zone - viewportY) / zone)
        } else if viewportY > bottom - zone {
            direction = 1
            proximity = min(1, (viewportY - (bottom - zone)) / zone)
        }
        guard direction != 0 else { return }

        let inset = collectionView.adjustedContentInset
        let minOffset = -inset.top
        let maxOffset = max(minOffset, collectionView.contentSize.height - collectionView.bounds.height + inset.bottom)
        let delta = direction * Metrics.maxScrollSpeed * proximity * CGFloat(link.targetTimestamp - link.timestamp)
        let newY = min(max(collectionView.contentOffset.y + delta, minOffset), maxOffset)
        guard newY != collectionView.contentOffset.y else { return }

        collectionView.contentOffset.y = newY
        moved(recognizer)   // the content moved under a still finger
    }
}
