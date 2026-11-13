//
//  DeclutteringWidget.swift
//  DeclutteringWidget
//

import WidgetKit
import SwiftUI
import Photos
import AppIntents

// MARK: - Entry

struct MemoryEntry: TimelineEntry {
    enum Content {
        case photo(UIImage, date: Date, id: String)
        case noAccess
        case empty
    }

    let date: Date
    let content: Content
}

// MARK: - Provider

struct Provider: TimelineProvider {
    private let maxEntries = 8
    private let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: .now, content: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        completion(makeEntries(count: 1).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        let entries = makeEntries(count: maxEntries)
        let calendar = Calendar.current
        let midnight = calendar.nextDate(after: .now, matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        let next = min((entries.last?.date ?? .now).addingTimeInterval(refreshInterval), midnight)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func makeEntries(count: Int) -> [MemoryEntry] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return [MemoryEntry(date: .now, content: .noAccess)]
        }

        // Photos kept in the app (or from the widget's own Keep button) don't come back
        let kept = DecisionStore.keptIDsSnapshot()
        let sections = PhotoLibraryService().loadOnThisDay()
        let assets = interleave(sections.map { $0.assets.filter { !kept.contains($0.localIdentifier) } }, limit: count)
        guard !assets.isEmpty else {
            return [MemoryEntry(date: .now, content: .empty)]
        }

        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let side: CGFloat = 600
        var entries: [MemoryEntry] = []
        for asset in assets {
            var image: UIImage?
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                                  contentMode: .aspectFill, options: options) { result, _ in image = result }
            guard let image, let created = asset.creationDate else { continue }
            let entryDate = Date.now.addingTimeInterval(refreshInterval * Double(entries.count))
            entries.append(MemoryEntry(date: entryDate, content: .photo(image, date: created, id: asset.localIdentifier)))
        }
        return entries.isEmpty ? [MemoryEntry(date: .now, content: .empty)] : entries
    }

    /// Takes one photo per year in turn so every year is represented.
    private func interleave(_ groups: [[PHAsset]], limit: Int) -> [PHAsset] {
        var result: [PHAsset] = []
        var index = 0
        while result.count < limit {
            var added = false
            for group in groups where index < group.count {
                result.append(group[index])
                added = true
                if result.count == limit { break }
            }
            if !added { break }
            index += 1
        }
        return result
    }
}

// MARK: - View

struct DeclutteringWidgetEntryView: View {
    let entry: MemoryEntry

    private var cream: Color { Color(BoothTheme.paper) }
    private var wine: Color { Color(BoothTheme.ink) }
    private var onBackground: Color { Color(BoothTheme.onBackground) }

    private func themed(_ size: CGFloat, _ weight: UIFont.Weight) -> Font {
        Font(BoothTheme.font(size, weight, scaling: false))
    }

    var body: some View {
        switch entry.content {
        case .photo(let image, let date, let id):
            VStack(spacing: 6) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(yearsAgoText(for: date))
                            .font(themed(14, .heavy))
                            .foregroundStyle(wine)
                        Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(themed(10, .semibold))
                            .foregroundStyle(wine.opacity(0.75))
                    }
                    Spacer(minLength: 0)
                    // Interactive: keeps this photo without opening the app
                    Button(intent: KeepPhotoIntent(assetID: id)) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cream)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(wine))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Keep this photo")
                }
                .frame(height: 28)
            }
            .padding(8)
        case .noAccess:
            message("Open Decluttering and allow Full Access to Photos", icon: "lock.fill")
        case .empty:
            message("Nothing to bin from this day.\nSnap. Sort. Bin.", icon: "sparkles")
        }
    }

    private func message(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(wine)
                .frame(width: 40, height: 40)
                .background(Circle().fill(cream))
            Text(text)
                .font(themed(12, .semibold))
                .foregroundStyle(onBackground)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func yearsAgoText(for date: Date) -> String {
        let years = Calendar.current.component(.year, from: .now) - Calendar.current.component(.year, from: date)
        switch years {
        case 0: return "Today"
        case 1: return "1 year ago"
        default: return "\(years) years ago"
        }
    }
}

// MARK: - Widget

struct DeclutteringWidget: Widget {
    let kind = "DeclutteringWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DeclutteringWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if case .photo = entry.content { Color(BoothTheme.surface) } else { Color(BoothTheme.current.background.base) }
                }
        }
        .configurationDisplayName("On This Day")
        .description("Photos from this day in past years.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    DeclutteringWidget()
} timeline: {
    MemoryEntry(date: .now, content: .empty)
    MemoryEntry(date: .now, content: .noAccess)
}
