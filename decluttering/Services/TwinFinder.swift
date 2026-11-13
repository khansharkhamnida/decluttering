import Photos
import CoreML
import UIKit
import Vision

/// Spots look-alike photos: taken within a minute or so of each other and similar according to
/// Vision image feature prints. Requiring both keeps unrelated photos from being matched.
nonisolated enum TwinFinder {

    struct Batch: @unchecked Sendable {
        let perYear: [[PHAsset]]
    }

    /// Lower means "more alike". Photos closer than this count as twins.
    /// A starting point to tune on real photos: the simulator can't produce real feature prints.
    static let threshold: Float = 0.5

    /// Twins are retakes and bursts, so they are shot close together in time.
    static let maxGap: TimeInterval = 90
    private static let maxPhotosPerYear = 60

    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [[[String]]]
        init(count: Int) { items = Array(repeating: [], count: count) }
        func set(_ groups: [[String]], at index: Int) { lock.lock(); items[index] = groups; lock.unlock() }
        func all() -> [[String]] { lock.lock(); defer { lock.unlock() }; return items.flatMap { $0 } }
    }

    /// Each group holds the ids of photos that look alike, earliest first.
    static func groups(in batch: Batch) -> [[String]] {
        let collected = Collected(count: batch.perYear.count)
        DispatchQueue.concurrentPerform(iterations: batch.perYear.count) { index in
            collected.set(groups(for: batch.perYear[index]), at: index)
        }
        return collected.all()
    }

    private static func groups(for assets: [PHAsset]) -> [[String]] {
        let photos = assets.filter { $0.mediaType == .image }.prefix(maxPhotosPerYear)
        var prints: [(id: String, date: Date, observation: VNFeaturePrintObservation)] = []
        for asset in photos {
            guard let date = asset.creationDate, let observation = featurePrint(for: asset) else { continue }
            prints.append((asset.localIdentifier, date, observation))
        }
        guard prints.count > 1 else { return [] }

        // Union-find: photos closer than the threshold end up in one group
        var parent = Array(0..<prints.count)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current { parent[current] = parent[parent[current]]; current = parent[current] }
            return current
        }
        for first in 0..<prints.count {
            for second in (first + 1)..<prints.count {
                guard abs(prints[first].date.timeIntervalSince(prints[second].date)) < maxGap else { continue }
                var distance: Float = .greatestFiniteMagnitude
                try? prints[first].observation.computeDistance(&distance, to: prints[second].observation)
                if distance < threshold { parent[root(second)] = root(first) }
            }
        }

        var grouped: [Int: [String]] = [:]
        let ordered = prints.indices.sorted { prints[$0].date < prints[$1].date }
        for index in ordered { grouped[root(index), default: []].append(prints[index].id) }
        return grouped.values.filter { $0.count > 1 }
    }

    private static func featurePrint(for asset: PHAsset) -> VNFeaturePrintObservation? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false // photos that only live in iCloud are skipped to keep this quick

        var image: CGImage?
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 299, height: 299),
                                              contentMode: .aspectFit, options: options) { result, _ in
            image = result?.cgImage
        }
        guard let image else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine, so ask Vision to run on the CPU instead
        for (stage, devices) in (try? request.supportedComputeStageDevices) ?? [:] {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        #endif
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return request.results?.first
    }
}
