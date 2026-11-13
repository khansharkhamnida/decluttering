import Foundation

enum MediaKind {
    case photo
    case livePhoto
    case video
}

struct MemoryItem {
    let id: String
    var kind: MediaKind = .photo
    var duration: TimeInterval = 0
    var isScreenshot = false

    /// Every item belongs to exactly one type, so the filter chips never overlap.
    var mediaFilter: MediaFilter {
        if isScreenshot { return .screenshots }
        switch kind {
        case .video: return .videos
        case .livePhoto: return .livePhotos
        case .photo: return .photos
        }
    }
}

struct MemorySection {
    let date: Date
    let yearsAgo: Int
    let items: [MemoryItem]
    /// Overrides the year as the folder title (used by shelves that aren't grouped by year).
    var label: String? = nil
}

enum PhotoAccess {
    case notDetermined
    case denied
    case limited
    case full
}

enum DeleteResult {
    case deleted
    case cancelled
}

/// Narrows today's memories to one type of media. Everything stays inside its year's folder.
enum MediaFilter: CaseIterable {
    case all
    case photos
    case livePhotos
    case videos
    case screenshots

    var title: String {
        switch self {
        case .all: return "All"
        case .photos: return "Photos"
        case .livePhotos: return "Live"
        case .videos: return "Videos"
        case .screenshots: return "Screenshots"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .photos: return "photo"
        case .livePhotos: return "livephoto"
        case .videos: return "video"
        case .screenshots: return "camera.viewfinder"
        }
    }

    func matches(_ item: MemoryItem) -> Bool {
        self == .all || item.mediaFilter == self
    }
}

/// One year of today's date that swipe sort can go through.
struct YearOption: Equatable {
    let key: String
    let title: String
    let subtitle: String
    let count: Int
}

enum YearChoice: Equatable {
    case all
    case year(String)
}
