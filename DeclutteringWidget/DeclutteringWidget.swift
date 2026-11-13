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
        /// Nothing left to sort for today. `hadPhotos` is false when no past year has a photo from this date.
        case caughtUp(streak: Int, hadPhotos: Bool)
    }

    let date: Date
    let content: Content
}

// MARK: - Provider

struct Provider: TimelineProvider {
    private let maxEntries = 8
    private let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: .now, content: .caughtUp(streak: 0, hadPhotos: true))
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
        let hadPhotos = sections.contains { !$0.assets.isEmpty }
        let caughtUp = [MemoryEntry(date: .now, content: .caughtUp(streak: DecisionStore.streakSnapshot(), hadPhotos: hadPhotos))]
        guard !assets.isEmpty else { return caughtUp }

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
        return entries.isEmpty ? caughtUp : entries
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
    @Environment(\.widgetFamily) private var family

    private var cream: Color { Color(BoothTheme.paper) }
    private var wine: Color { Color(BoothTheme.ink) }
    private var onBackground: Color { Color(BoothTheme.onBackground) }
    private var themeBackground: Color { Color(BoothTheme.current.background.base) }

    private func themed(_ size: CGFloat, _ weight: UIFont.Weight) -> Font {
        Font(BoothTheme.font(size, weight, scaling: false))
    }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var background: some View {
        if case .photo = entry.content, family == .systemMedium { cream } else { themeBackground }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .photo(let image, let date, let id):
            if family == .systemMedium {
                sideBySide(image: image, date: date, id: id)
            } else {
                pillCard(image: image, date: date, id: id)
            }
        case .noAccess:
            message("Open Decluttering and allow Full Access to Photos", icon: "lock.fill")
        case .caughtUp(let streak, let hadPhotos):
            caughtUp(streak: streak, hadPhotos: hadPhotos)
        }
    }

    // MARK: Photo layouts

    /// Small and large: the photo sits inside the theme colour with one small label on top.
    private func pillCard(image: UIImage, date: Date, id: String) -> some View {
        let large = family == .systemLarge
        return framedPhoto(image, radius: large ? 30 : 22)
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    Text(yearsAgoText(for: date))
                        .font(themed(large ? 17 : 13, .heavy))
                        .foregroundStyle(wine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    keepButton(id: id, size: large ? 34 : 26)
                }
                .padding(.leading, 12)
                .padding(5)
                .background(Capsule().fill(cream.opacity(0.94)))
                .padding(large ? 10 : 7)
            }
            .padding(large ? 14 : 10)
    }

    /// Medium: photo on the left, when and Keep on the right.
    private func sideBySide(image: UIImage, date: Date, id: String) -> some View {
        HStack(spacing: 12) {
            framedPhoto(image, radius: 18)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 2) {
                Text(yearsAgoText(for: date))
                    .font(themed(22, .heavy))
                    .foregroundStyle(wine)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(themed(12, .semibold))
                    .foregroundStyle(wine.opacity(0.75))
                Spacer(minLength: 0)
                Button(intent: KeepPhotoIntent(assetID: id)) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                        Text("Keep")
                    }
                    .font(themed(13, .heavy))
                    .foregroundStyle(cream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(wine))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Keep this photo")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .padding(12)
    }

    private func framedPhoto(_ image: UIImage, radius: CGFloat) -> some View {
        Color.clear
            .overlay { Image(uiImage: image).resizable().scaledToFill() }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Interactive: keeps this photo without opening the app.
    private func keepButton(id: String, size: CGFloat) -> some View {
        Button(intent: KeepPhotoIntent(assetID: id)) {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(cream)
                .frame(width: size, height: size)
                .background(Circle().fill(wine))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep this photo")
    }

    // MARK: Messages

    private func caughtUp(streak: Int, hadPhotos: Bool) -> some View {
        let title = hadPhotos ? "All sorted for today." : "No photos from this day."
        let streakLine = streak > 0 ? "\(streak)-day streak" : "Sort a photo to start a streak"
        return VStack(spacing: 6) {
            BinnyMark()
                .frame(maxHeight: family == .systemSmall ? 52 : 80)
            Text(title)
                .font(themed(family == .systemSmall ? 12 : 14, .heavy))
                .foregroundStyle(onBackground)
                .multilineTextAlignment(.center)
            Label(streakLine, systemImage: "flame.fill")
                .font(themed(family == .systemSmall ? 10 : 12, .semibold))
                .foregroundStyle(onBackground.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    MemoryEntry(date: .now, content: .caughtUp(streak: 3, hadPhotos: true))
    MemoryEntry(date: .now, content: .caughtUp(streak: 0, hadPhotos: false))
    MemoryEntry(date: .now, content: .noAccess)
}
