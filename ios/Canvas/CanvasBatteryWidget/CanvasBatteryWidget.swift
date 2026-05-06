import Apollo
import ApolloAPI
import CanvasGraphQL
import SwiftUI
import UIKit
import WidgetKit

private enum CanvasWidgetStore {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let batteryPercentageKey = "canvas.battery.percentage"
    static let lastFullChargeDateKey = "canvas.battery.last-full-charge-date"
    static let widgetBackgroundPositionKey = "canvas.widget.background.position"
    static let widgetSafeAreaTopKey = "canvas.widget.safe-area.top"
    static let lastPullDateKey = "canvas.battery.last-pull-date"
    static let playlistDisplayedKey = "canvas.playlist.displayed"
    static let playlistTotalKey = "canvas.playlist.total"
    static let widgetBackgroundImageFilename = "canvas-widget-background.png"
    static let defaultServerURL = "http://192.168.0.165:3000"
}

private enum WidgetBackgroundPosition: String {
    case topLeft = "top-left"
    case topRight = "top-right"
    case middleLeft = "middle-left"
    case middleRight = "middle-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"

    var rowIndex: Int {
        switch self {
        case .topLeft, .topRight:
            return 0
        case .middleLeft, .middleRight:
            return 1
        case .bottomLeft, .bottomRight:
            return 2
        }
    }

    var columnIndex: Int {
        switch self {
        case .topLeft, .middleLeft, .bottomLeft:
            return 0
        case .topRight, .middleRight, .bottomRight:
            return 1
        }
    }
}

private struct CanvasBatteryEntry: TimelineEntry {
    let date: Date
    let percentage: Int?
    let lastFullChargeDate: Date?
    let lastPullDate: Date?
    let playlistDisplayed: Int?
    let playlistTotal: Int?
}

private struct CanvasBatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> CanvasBatteryEntry {
        CanvasBatteryEntry(date: Date(), percentage: 72, lastFullChargeDate: nil, lastPullDate: nil, playlistDisplayed: 22, playlistTotal: 45)
    }

    func getSnapshot(in context: Context, completion: @escaping (CanvasBatteryEntry) -> Void) {
        Task {
            completion(await buildEntry(displaySize: context.displaySize))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CanvasBatteryEntry>) -> Void) {
        Task {
            let entry = await buildEntry(displaySize: context.displaySize)
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func buildEntry(displaySize: CGSize) async -> CanvasBatteryEntry {
        let resolved = await resolveDeviceData()
        return CanvasBatteryEntry(
            date: Date(),
            percentage: resolved.percentage,
            lastFullChargeDate: resolved.lastChargeDate,
            lastPullDate: resolved.lastPullDate,
            playlistDisplayed: resolved.playlistDisplayed,
            playlistTotal: resolved.playlistTotal
        )
    }

    private func resolveDeviceData() async -> (
        percentage: Int?,
        lastChargeDate: Date?,
        lastPullDate: Date?,
        playlistDisplayed: Int?,
        playlistTotal: Int?
    ) {
        let cachedPercentage = readCachedBatteryPercentage()
        let cachedChargeDate = readCachedLastFullChargeDate()
        let cachedPullDate = readCachedLastPullDate()
        let cachedDisplayed = readCachedPlaylistDisplayed()
        let cachedTotal = readCachedPlaylistTotal()

        guard let baseURL = validatedServerURL() else {
            return (cachedPercentage, cachedChargeDate, cachedPullDate, cachedDisplayed, cachedTotal)
        }

        let client = WidgetGraphQLClient.client(for: baseURL)
        async let battery = fetchBatteryData(client: client)
        async let playlist = fetchPlaylistProgress(client: client)

        let batteryResult = await battery
        let playlistResult = await playlist

        let percentage = batteryResult?.percentage ?? cachedPercentage
        let chargeDate = batteryResult?.lastChargeDate ?? cachedChargeDate
        let pullDate = batteryResult?.lastPullDate ?? cachedPullDate

        if let batteryResult {
            persistBatteryPercentage(batteryResult.percentage)
            if let date = batteryResult.lastChargeDate {
                persistLastFullChargeDate(date)
            }
            if let date = batteryResult.lastPullDate {
                persistLastPullDate(date)
            }
        }

        let displayed: Int?
        let total: Int?
        switch playlistResult {
        case let .some(.found(d, t)):
            displayed = d
            total = t
            persistPlaylistProgress(displayed: d, total: t)
        case .some(.notFound):
            displayed = nil
            total = nil
            clearPlaylistProgress()
        case .none:
            displayed = cachedDisplayed
            total = cachedTotal
        }

        return (percentage, chargeDate, pullDate, displayed, total)
    }

    private enum PlaylistFetchResult {
        case found(displayed: Int, total: Int)
        case notFound
    }

    private func validatedServerURL() -> URL? {
        guard
            let url = URL(string: readServerURL()),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return nil
        }
        return url
    }

    private func fetchBatteryData(client: ApolloClient) async -> (percentage: Int, lastChargeDate: Date?, lastPullDate: Date?)? {
        do {
            let data = try await widgetFetch(client: client, query: CanvasGraphQL.CanvasBatteryWidgetQuery())
            guard
                let battery = data.canvasBattery,
                let percentage = Int(battery.percentage)
            else {
                return nil
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let chargeDate = battery.lastFullChargeDate.flatMap { formatter.date(from: $0) }
            let pullDate = battery.lastPullDate.flatMap { formatter.date(from: $0) }
            return (percentage, chargeDate, pullDate)
        } catch {
            return nil
        }
    }

    private func fetchPlaylistProgress(client: ApolloClient) async -> PlaylistFetchResult? {
        do {
            let data = try await widgetFetch(client: client, query: CanvasGraphQL.PlaylistProgressQuery())
            guard let progress = data.playlistProgress else { return .notFound }
            return .found(displayed: progress.displayed, total: progress.total)
        } catch {
            return nil
        }
    }

    private func resolveBackgroundImage(displaySize: CGSize) -> UIImage? {
        guard
            let screenshot = readBackgroundScreenshot(),
            let position = readBackgroundPosition()
        else {
            return nil
        }

        let safeAreaTop = readSafeAreaTopInset()
        return cropBackground(
            screenshot: screenshot,
            widgetSize: displaySize,
            safeAreaTopInset: safeAreaTop,
            position: position
        )
    }

    private func cropBackground(
        screenshot: UIImage,
        widgetSize: CGSize,
        safeAreaTopInset: CGFloat,
        position: WidgetBackgroundPosition
    ) -> UIImage? {
        guard let sourceCGImage = screenshot.cgImage else {
            return nil
        }

        let scale = screenshot.scale
        let screenSize = CGSize(
            width: CGFloat(sourceCGImage.width) / scale,
            height: CGFloat(sourceCGImage.height) / scale
        )

        guard screenSize.width > 0, screenSize.height > 0 else {
            return nil
        }

        let pixelsPerPointX = CGFloat(sourceCGImage.width) / screenSize.width
        let pixelsPerPointY = CGFloat(sourceCGImage.height) / screenSize.height

        let horizontalInset: CGFloat = 25
        let topInset: CGFloat = 30
        let horizontalSpacing: CGFloat = 38.2
        let verticalSpacing: CGFloat = 23

        let originX = horizontalInset + CGFloat(position.columnIndex) * (widgetSize.width + horizontalSpacing)
        let originY = safeAreaTopInset + topInset + CGFloat(position.rowIndex) * (widgetSize.height + verticalSpacing)

        let cropRect = CGRect(
            x: originX * pixelsPerPointX,
            y: originY * pixelsPerPointY,
            width: widgetSize.width * pixelsPerPointX,
            height: widgetSize.height * pixelsPerPointY
        ).integral

        let imageBounds = CGRect(x: 0, y: 0, width: sourceCGImage.width, height: sourceCGImage.height)
        let boundedCropRect = cropRect.intersection(imageBounds)
        guard boundedCropRect.width > 1, boundedCropRect.height > 1 else {
            return nil
        }

        guard let croppedImage = sourceCGImage.cropping(to: boundedCropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedImage, scale: screenshot.scale, orientation: .up)
    }

    private func readServerURL() -> String {
        if let sharedServerURL = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.string(forKey: CanvasWidgetStore.serverURLKey) {
            return sharedServerURL
        }

        return CanvasWidgetStore.defaultServerURL
    }

    private func readCachedBatteryPercentage() -> Int? {
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.object(forKey: CanvasWidgetStore.batteryPercentageKey) as? Int
    }

    private func persistBatteryPercentage(_ percentage: Int) {
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.set(percentage, forKey: CanvasWidgetStore.batteryPercentageKey)
    }

    private func readCachedLastFullChargeDate() -> Date? {
        guard let timestamp = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.object(forKey: CanvasWidgetStore.lastFullChargeDateKey) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func persistLastFullChargeDate(_ date: Date) {
        let timestamp = date.timeIntervalSince1970
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.set(timestamp, forKey: CanvasWidgetStore.lastFullChargeDateKey)
    }

    private func readCachedLastPullDate() -> Date? {
        guard let timestamp = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.object(forKey: CanvasWidgetStore.lastPullDateKey) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func persistLastPullDate(_ date: Date) {
        let timestamp = date.timeIntervalSince1970
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.set(timestamp, forKey: CanvasWidgetStore.lastPullDateKey)
    }

    private func readCachedPlaylistDisplayed() -> Int? {
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.object(forKey: CanvasWidgetStore.playlistDisplayedKey) as? Int
    }

    private func readCachedPlaylistTotal() -> Int? {
        UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.object(forKey: CanvasWidgetStore.playlistTotalKey) as? Int
    }

    private func persistPlaylistProgress(displayed: Int, total: Int) {
        let defaults = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)
        defaults?.set(displayed, forKey: CanvasWidgetStore.playlistDisplayedKey)
        defaults?.set(total, forKey: CanvasWidgetStore.playlistTotalKey)
    }

    private func clearPlaylistProgress() {
        let defaults = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)
        defaults?.removeObject(forKey: CanvasWidgetStore.playlistDisplayedKey)
        defaults?.removeObject(forKey: CanvasWidgetStore.playlistTotalKey)
    }

    private func readBackgroundPosition() -> WidgetBackgroundPosition? {
        let rawValue = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.string(forKey: CanvasWidgetStore.widgetBackgroundPositionKey)
        return WidgetBackgroundPosition(rawValue: rawValue ?? "")
    }

    private func readSafeAreaTopInset() -> CGFloat {
        let rawValue = UserDefaults(suiteName: CanvasWidgetStore.appGroupSuiteName)?.double(forKey: CanvasWidgetStore.widgetSafeAreaTopKey) ?? 0
        return CGFloat(rawValue)
    }

    private func readBackgroundScreenshot() -> UIImage? {
        guard
            let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CanvasWidgetStore.appGroupSuiteName)
        else {
            return nil
        }

        let screenshotURL = containerURL.appendingPathComponent(CanvasWidgetStore.widgetBackgroundImageFilename)
        guard let imageData = try? Data(contentsOf: screenshotURL) else {
            return nil
        }

        return UIImage(data: imageData)
    }
}

// Local Apollo client + async fetch helpers, scoped to the widget extension.
// Duplicates a tiny piece of GraphQLClient.swift to keep the widget binary
// self-contained (it cannot import sibling Canvas-target files).
private enum WidgetGraphQLClient {
    static func client(for baseURL: URL) -> ApolloClient {
        let url = baseURL.appendingPathComponent("graphql")
        let store = ApolloStore()
        let provider = DefaultInterceptorProvider(store: store)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        return ApolloClient(networkTransport: transport, store: store)
    }
}

private enum WidgetGraphQLError: Error {
    case server
    case empty
}

private func widgetFetch<Q: GraphQLQuery>(client: ApolloClient, query: Q) async throws -> Q.Data {
    try await withCheckedThrowingContinuation { continuation in
        client.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in
            switch result {
            case let .success(graphQLResult):
                if let _ = graphQLResult.errors?.first {
                    continuation.resume(throwing: WidgetGraphQLError.server)
                    return
                }
                if let data = graphQLResult.data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: WidgetGraphQLError.empty)
                }
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }
}

private struct CanvasBatteryWidgetView: View {
    let entry: CanvasBatteryProvider.Entry
    @Environment(\.widgetRenderingMode) var renderingMode
    @Environment(\.widgetFamily) var widgetFamily

    private func ringSize(in geometry: GeometryProxy) -> CGFloat {
        switch widgetFamily {
        case .systemSmall:
            return geometry.size.height * 0.52
        case .systemMedium:
            return geometry.size.height * 0.50
        case .systemLarge:
            return geometry.size.height * 0.27
        default:
            return geometry.size.height * 0.42
        }
    }

    private func ringStrokeWidth(for size: CGFloat) -> CGFloat {
        return size * 0.125
    }

    private var batteryProgress: Double {
        guard let percentage = entry.percentage else { return 0 }
        return min(max(Double(percentage) / 100, 0), 1)
    }

    private var batteryRingColor: Color {
        guard let percentage = entry.percentage else {
            return Color.white.opacity(0.20)
        }

        switch percentage {
        case 0 ... 20:
            return .red
        case 21 ... 40:
            return .orange
        default:
            return .green
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                widgetContent(in: geometry)
                VStack(alignment: .trailing, spacing: 2) {
                    daysIndicator
                }
            }
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func widgetContent(in geometry: GeometryProxy) -> some View {
        let horizontalGap = geometry.size.width * 0.03

        Group {
            if widgetFamily == .systemSmall {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        batteryRingView(size: ringSize(in: geometry))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        batteryPercentageView(in: geometry)
                    }

                    bottomRow
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: horizontalGap) {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                batteryRingView(size: ringSize(in: geometry))
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                batteryPercentageView(in: geometry)
                            }
                        }

                        if widgetFamily == .systemLarge {
                            VStack(alignment: .leading, spacing: 0) {
                                widgetTitleView
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }

                    Spacer(minLength: 0)
                    bottomRow
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var daysIndicator: some View {
        Group {
            if let lastChargeDate = entry.lastFullChargeDate {
                let days = Calendar.current.dateComponents([.day], from: lastChargeDate, to: Date()).day ?? 0

                Text("\(days)j", comment: "Days since last charge, shown in widget")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
    }

    private var playlistProgressIndicator: some View {
        Group {
            if let total = entry.playlistTotal,
               let displayed = entry.playlistDisplayed,
               total > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "photo.stack")
                        .font(.caption2)
                    Text("\(displayed) / \(total)", comment: "Playlist progress: displayed of total")
                        .font(.caption)
                }
                .foregroundStyle(.primary.opacity(0.7))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            lastPullIndicator
            Spacer(minLength: 4)
            playlistProgressIndicator
        }
    }

    private var lastPullIndicator: some View {
        Group {
            if let lastPullDate = entry.lastPullDate {
                Text(lastPullDate, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.5))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
    }

    private func batteryRingView(size: CGFloat) -> some View {
        let strokeWidth = ringStrokeWidth(for: size)

        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: batteryProgress)
                .stroke(
                    batteryRingColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: size * 0.35, weight: .regular))
                .foregroundStyle(Color.primary)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
    }

    private func batteryPercentageView(in geometry: GeometryProxy) -> some View {
        let fontSize: CGFloat
        if widgetFamily == .systemSmall {
            fontSize = geometry.size.height * 0.30
        } else {
            fontSize = geometry.size.height * 0.40
        }

        return Group {
            if let percentage = entry.percentage {
                Text("\(percentage)%")
                    .font(.system(size: fontSize, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .padding(.top, widgetFamily == .systemSmall ? 5 : 10)
            } else {
                Text("--")
                    .font(.system(size: fontSize, weight: .regular, design: .default))
                    .foregroundStyle(.primary.opacity(0.5))
            }
        }
    }

    private var widgetTitleView: some View {
        Text("Canvas Battery")
            .font(.headline)
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .widgetAccentable()
    }
}

@main
struct CanvasBatteryWidget: Widget {
    private let kind = "CanvasBatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CanvasBatteryProvider()) { entry in
            CanvasBatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Canvas Battery")
        .description("Displays the latest Canvas battery level.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .containerBackgroundRemovable(true)
    }
}

#Preview("Small", as: .systemSmall) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -2, to: .now), lastPullDate: Calendar.current.date(byAdding: .hour, value: -2, to: .now), playlistDisplayed: 12, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -5, to: .now), lastPullDate: Calendar.current.date(byAdding: .hour, value: -6, to: .now), playlistDisplayed: 28, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: 8, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -10, to: .now), lastPullDate: Calendar.current.date(byAdding: .day, value: -1, to: .now), playlistDisplayed: 44, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: nil, lastFullChargeDate: nil, lastPullDate: nil, playlistDisplayed: nil, playlistTotal: nil)
}

#Preview("Medium", as: .systemMedium) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -3, to: .now), lastPullDate: Calendar.current.date(byAdding: .hour, value: -3, to: .now), playlistDisplayed: 12, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -7, to: .now), lastPullDate: Calendar.current.date(byAdding: .hour, value: -12, to: .now), playlistDisplayed: 28, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: 8, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -14, to: .now), lastPullDate: Calendar.current.date(byAdding: .day, value: -2, to: .now), playlistDisplayed: 44, playlistTotal: 45)
}

#Preview("Large", as: .systemLarge) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -1, to: .now), lastPullDate: Calendar.current.date(byAdding: .minute, value: -30, to: .now), playlistDisplayed: 22, playlistTotal: 45)
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -4, to: .now), lastPullDate: Calendar.current.date(byAdding: .hour, value: -5, to: .now), playlistDisplayed: 33, playlistTotal: 45)
}
