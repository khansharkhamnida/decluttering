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
        let next = WidgetLogic.nextRefreshDate(lastEntryDate: entries.last?.date, refreshInterval: refreshInterval)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func makeEntries(count: Int) -> [MemoryEntry] {
        let library = PhotoLibraryService()
        // Photos kept in the app (or from the widget's own Keep button) don't come back
        let plan = WidgetLogic.plan(hasAccess: WidgetLogic.hasAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite)),
                                    keptIDs: DecisionStore.keptIDsSnapshot(),
                                    limit: count,
                                    id: { $0.localIdentifier },
                                    loadGroups: { library.loadOnThisDay().map(\.assets) })
        let assets: [PHAsset]
        switch plan {
        case .noAccess:
            return [MemoryEntry(date: .now, content: .noAccess)]
        case .caughtUp(let hadPhotos):
            return [caughtUpEntry(hadPhotos: hadPhotos)]
        case .photos(let planned):
            assets = planned
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
        return entries.isEmpty ? [caughtUpEntry(hadPhotos: true)] : entries
    }

    private func caughtUpEntry(hadPhotos: Bool) -> MemoryEntry {
        MemoryEntry(date: .now, content: .caughtUp(streak: DecisionStore.streakSnapshot(), hadPhotos: hadPhotos))
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
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photoDescription(for: date))
            .accessibilityAddTraits(.isImage)
            .overlay(alignment: .bottom) {
                HStack(spacing: 6) {
                    Text(yearsAgoText(for: date))
                        .font(themed(large ? 17 : 13, .heavy))
                        .foregroundStyle(wine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true)
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(photoDescription(for: date))
                .accessibilityAddTraits(.isImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(yearsAgoText(for: date))
                    .font(themed(22, .heavy))
                    .foregroundStyle(wine)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityHidden(true)
                Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(themed(12, .semibold))
                    .foregroundStyle(wine.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button(intent: KeepPhotoIntent(assetID: id)) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .accessibilityHidden(true)
                        Text("Keep")
                            .lineLimit(1)
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
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Keep this photo")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Messages

    private func caughtUp(streak: Int, hadPhotos: Bool) -> some View {
        let title = hadPhotos ? "All sorted for today." : "No photos from this day."
        let streakLine = WidgetLogic.streakLine(streak)
        return VStack(spacing: 6) {
            BinnyMark()
                .frame(maxHeight: family == .systemSmall ? 52 : 80)
            Text(title)
                .font(themed(family == .systemSmall ? 12 : 14, .heavy))
                .foregroundStyle(onBackground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Label(streakLine, systemImage: "flame.fill")
                .font(themed(family == .systemSmall ? 10 : 12, .semibold))
                .foregroundStyle(onBackground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(streakLine)")
    }

    private func message(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(wine)
                .frame(width: 40, height: 40)
                .background(Circle().fill(cream))
                .accessibilityHidden(true)
            Text(text)
                .font(themed(12, .semibold))
                .foregroundStyle(onBackground)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func photoDescription(for date: Date) -> String {
        "Photo from \(yearsAgoText(for: date).lowercased()), \(date.formatted(.dateTime.day().month(.wide).year()))"
    }

    private func yearsAgoText(for date: Date) -> String {
        WidgetLogic.yearsAgoText(for: date)
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
