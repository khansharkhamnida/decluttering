import AVFoundation
import UIKit
import Photos
import WidgetKit

final class OnThisDayInteractor: OnThisDayInteractorProtocol {

    private let service: PhotoLibraryService
    private let imageManager = PHCachingImageManager()
    private var assetsByID: [String: PHAsset] = [:]
    private var loadCounter = 0

    // .fast keeps Photos from decoding bigger images than the thumbnail needs
    private static let fullImageOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()

    private static let thumbnailOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()

    init(service: PhotoLibraryService = PhotoLibraryService()) {
        self.service = service
    }

    var access: PhotoAccess {
        Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async -> PhotoAccess {
        Self.map(await service.requestAccess())
    }

    func loadSections(dayOffset: Int) async -> [MemorySection] {
        loadCounter += 1
        let token = loadCounter
        let calendar = Calendar.current
        // "Years ago" counts from the chosen day, so 10 Nov 2025 is "1 year ago" whichever day is picked
        let target = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
        let currentYear = calendar.component(.year, from: target)
        let service = self.service

        // PhotoKit queries are slow on big libraries, so keep them off the main thread
        let loaded: [YearSection] = await Self.background { service.loadOnThisDay(dayOffset: dayOffset) }

        var lookup: [String: PHAsset] = [:]
        let sections = loaded.map { section in
            section.assets.forEach { lookup[$0.localIdentifier] = $0 }
            return MemorySection(date: section.date,
                                 yearsAgo: currentYear - calendar.component(.year, from: section.date),
                                 items: section.assets.map(Self.item(for:)))
        }
        // A newer load may have started while this one was running; only the latest owns the lookup
        if token == loadCounter { assetsByID = lookup }
        return sections
    }

    private static func background<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: work()) }
        }
    }

    private static func item(for asset: PHAsset) -> MemoryItem {
        let kind: MediaKind = asset.mediaType == .video ? .video : (asset.mediaSubtypes.contains(.photoLive) ? .livePhoto : .photo)
        return MemoryItem(id: asset.localIdentifier, kind: kind, duration: asset.duration,
                          isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot))
    }

    func findTwins(in sections: [MemorySection]) async -> [[String]] {
        let batch = TwinFinder.Batch(perYear: sections.map { section in section.items.compactMap { assetsByID[$0.id] } })
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: TwinFinder.groups(in: batch))
            }
        }
    }

    func loadThumbnail(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? {
        guard let asset = assetsByID[id] else { completion(nil); return nil }
        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill,
                                         options: Self.thumbnailOptions) { image, _ in completion(image) }
    }

    func loadImage(id: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) -> ThumbnailToken? {
        guard let asset = assetsByID[id] else { completion(nil); return nil }
        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit,
                                         options: Self.fullImageOptions) { image, _ in completion(image) }
    }

    func cancelImage(_ token: ThumbnailToken) { imageManager.cancelImageRequest(token) }

    func loadPlayerItem(id: String, completion: @escaping (AVPlayerItem?) -> Void) -> ThumbnailToken? {
        guard let asset = assetsByID[id] else { completion(nil); return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return imageManager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
            DispatchQueue.main.async { completion(item) }
        }
    }

    func loadLivePhoto(id: String, targetSize: CGSize, completion: @escaping (PHLivePhoto?) -> Void) -> ThumbnailToken? {
        guard let asset = assetsByID[id] else { completion(nil); return nil }
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return imageManager.requestLivePhoto(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { live, _ in
            completion(live)
        }
    }

    func cancelThumbnail(_ token: ThumbnailToken) {
        imageManager.cancelImageRequest(token)
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let assets = ids.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: Self.thumbnailOptions)
    }

    func stopCaching(ids: [String], targetSize: CGSize) {
        let assets = ids.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }
        imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: Self.thumbnailOptions)
    }

    func delete(ids: [String]) async throws -> DeleteResult {
        let assets = ids.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return .cancelled }
        do {
            // iOS shows its own confirmation and moves items to Recently Deleted
            try await service.delete(assets)
            WidgetCenter.shared.reloadAllTimelines()
            return .deleted
        } catch let error as NSError where error.domain == PHPhotosErrorDomain && error.code == PHPhotosError.userCancelled.rawValue {
            return .cancelled
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAccess {
        switch status {
        case .authorized: return .full
        case .limited: return .limited
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
