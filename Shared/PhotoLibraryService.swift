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

    func delete(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
}
