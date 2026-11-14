import Photos

nonisolated struct YearSection {
    let date: Date
    let assets: [PHAsset]
}

nonisolated final class PhotoLibraryService: Sendable {

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [YearSection?]
        init(count: Int) { items = Array(repeating: nil, count: count) }
        func set(_ section: YearSection?, at index: Int) { lock.lock(); items[index] = section; lock.unlock() }
        func all() -> [YearSection] { lock.lock(); defer { lock.unlock() }; return items.compactMap { $0 } }
    }

    func requestAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current != .notDetermined { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// One section per year (newest first) containing photos taken on one day and month.
    /// `dayOffset` shifts that day from today (-3 is three days ago, 2 is the day after tomorrow).
    /// Blocking: call it off the main thread. Each year is queried in parallel.
    func loadOnThisDay(calendar: Calendar = .current, dayOffset: Int = 0) -> [YearSection] {
        guard let oldestYear = oldestPhotoYear(calendar: calendar) else { return [] }
        let target = calendar.date(byAdding: .day, value: dayOffset, to: .now) ?? .now
        let targetYear = calendar.component(.year, from: target)
        let totalYears = max(targetYear - oldestYear + 1, 1)
        let dates = DateFactory.generatePastDates(using: calendar, totalYears: totalYears, now: target)

        let results = Results(count: dates.count)
        DispatchQueue.concurrentPerform(iterations: dates.count) { index in
            results.set(fetchSection(for: dates[index], calendar: calendar), at: index)
        }
        return results.all()
    }

    private func fetchSection(for date: Date, calendar: Calendar) -> YearSection? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)
        guard result.count > 0 else { return nil }

        var assets = [PHAsset]()
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return YearSection(date: start, assets: assets)
    }

    private func oldestPhotoYear(calendar: Calendar) -> Int? {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit = 1
        guard let date = PHAsset.fetchAssets(with: options).firstObject?.creationDate else { return nil }
        return calendar.component(.year, from: date)
    }

    /// A check for "did this day have anything to sort?", used by the streak. Nil when photo access
    /// isn't granted, so callers can fall back to counting every day.
    /// A day counts as having photos if any year up to its own has a photo on that month and day.
    func hadPhotosPredicate(calendar: Calendar = .current) -> (@Sendable (Date) -> Bool)? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let oldestYear = oldestPhotoYear(calendar: calendar)
        return { [self] day in
            guard let oldestYear else { return false }
            return hasPhotos(on: day, oldestYear: oldestYear, calendar: calendar)
        }
    }

    private func hasPhotos(on day: Date, oldestYear: Int, calendar: Calendar) -> Bool {
        let year = calendar.component(.year, from: day)
        let dates = DateFactory.generatePastDates(using: calendar, totalYears: max(year - oldestYear + 1, 1), now: day)
        return dates.contains { hasAssets(on: $0, calendar: calendar) }
    }

    private func hasAssets(on date: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate
        )
        options.fetchLimit = 1
        return PHAsset.fetchAssets(with: options).count > 0
    }

    func delete(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
}

// MARK: Keepers album

extension PhotoLibraryService {

    /// Adds the photos to the album, creating it when it is missing. The album is found by its saved identifier
    /// first and by title second. Returns the album's identifier, or nil when nothing could be done.
    /// Never asks for permission: without access it does nothing.
    func addToAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws -> String? {
        guard !assetIDs.isEmpty, hasLibraryAccess else { return nil }
        if let album = findAlbum(title: title, knownAlbumID: knownAlbumID) {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
                guard assets.count > 0 else { return }
                PHAssetCollectionChangeRequest(for: album)?.addAssets(assets)
            }
            return album.localIdentifier
        }
        let placeholderID = PlaceholderID()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
            placeholderID.value = request.placeholderForCreatedAssetCollection.localIdentifier
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            if assets.count > 0 { request.addAssets(assets) }
        }
        return placeholderID.value
    }

    /// Takes the photos out of the album (they stay in the library). Does nothing when the album doesn't exist.
    func removeFromAlbum(assetIDs: [String], title: String, knownAlbumID: String?) async throws {
        guard !assetIDs.isEmpty, hasLibraryAccess,
              let album = findAlbum(title: title, knownAlbumID: knownAlbumID) else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            guard assets.count > 0 else { return }
            PHAssetCollectionChangeRequest(for: album)?.removeAssets(assets)
        }
    }

    private var hasLibraryAccess: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private func findAlbum(title: String, knownAlbumID: String?) -> PHAssetCollection? {
        if let knownAlbumID,
           let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [knownAlbumID], options: nil).firstObject {
            return album
        }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", title)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
    }

    private final class PlaceholderID: @unchecked Sendable {
        var value: String?
    }
}
