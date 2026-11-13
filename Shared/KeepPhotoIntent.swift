import AppIntents

/// The Keep heart on the widget. It records the decision without opening the app.
struct KeepPhotoIntent: AppIntent {

    static let title: LocalizedStringResource = "Keep this photo"
    static let isDiscoverable = false

    @Parameter(title: "Photo ID")
    var assetID: String

    init() {}

    init(assetID: String) {
        self.assetID = assetID
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run { DecisionStore.shared.recordKept(ids: [assetID]) }
        return .result()
    }
}
