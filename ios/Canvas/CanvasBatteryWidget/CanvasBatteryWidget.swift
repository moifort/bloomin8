import SwiftUI
import WidgetKit
import UIKit

private enum CanvasWidgetStore {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let batteryPercentageKey = "canvas.battery.percentage"
    static let lastFullChargeDateKey = "canvas.battery.last-full-charge-date"
    static let widgetBackgroundPositionKey = "canvas.widget.background.position"
    static let widgetSafeAreaTopKey = "canvas.widget.safe-area.top"
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

private struct CanvasBatteryResponseEnvelope: Decodable {
    struct BatteryData: Decodable {
        let percentage: Int
        let lastFullChargeDate: String?
    }

    enum Payload: Decodable {
        case batteryData(BatteryData)
        case unavailable

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let batteryData = try? container.decode(BatteryData.self) {
                self = .batteryData(batteryData)
                return
            }

            if let rawPercentage = try? container.decode(Int.self) {
                self = .batteryData(BatteryData(percentage: rawPercentage, lastFullChargeDate: nil))
                return
            }

            if let rawStatus = try? container.decode(String.self), rawStatus == "battery-unavailable" {
                self = .unavailable
                return
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported battery payload format."
            )
        }
    }

    let data: Payload?
}

private struct CanvasBatteryEntry: TimelineEntry {
    let date: Date
    let percentage: Int?
    let lastFullChargeDate: Date?
}

private struct CanvasBatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> CanvasBatteryEntry {
        CanvasBatteryEntry(date: Date(), percentage: 72, lastFullChargeDate: nil)
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
        let (percentage, lastChargeDate) = await resolveBatteryData()
        return CanvasBatteryEntry(date: Date(), percentage: percentage, lastFullChargeDate: lastChargeDate)
    }

    private func resolveBatteryData() async -> (percentage: Int?, lastChargeDate: Date?) {
        let cachedPercentage = readCachedBatteryPercentage()
        let cachedChargeDate = readCachedLastFullChargeDate()

        guard let (fetchedPercentage, fetchedChargeDate) = await fetchBatteryData() else {
            return (cachedPercentage, cachedChargeDate)
        }

        persistBatteryPercentage(fetchedPercentage)
        if let chargeDate = fetchedChargeDate {
            persistLastFullChargeDate(chargeDate)
        }
        return (fetchedPercentage, fetchedChargeDate ?? cachedChargeDate)
    }

    private func fetchBatteryData() async -> (percentage: Int, lastChargeDate: Date?)? {
        guard
            let baseURL = URL(string: readServerURL()),
            ["http", "https"].contains(baseURL.scheme?.lowercased())
        else {
            return nil
        }

        let endpoint = baseURL
            .appendingPathComponent("canvas")
            .appendingPathComponent("battery")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 12

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return nil
        }

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ..< 300).contains(httpResponse.statusCode),
            let envelope = try? JSONDecoder().decode(CanvasBatteryResponseEnvelope.self, from: data)
        else {
            return nil
        }

        guard let payload = envelope.data else {
            return nil
        }

        switch payload {
        case let .batteryData(batteryData):
            let chargeDate = batteryData.lastFullChargeDate.flatMap {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter.date(from: $0)
            }
            return (batteryData.percentage, chargeDate)
        case .unavailable:
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

        // Calculate screen size from the screenshot dimensions and scale
        // The screenshot is a full-screen capture, so we can derive the logical size
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

        // Fake transparency uses a Home Screen screenshot and crops the slot where the widget is placed.
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
        return size * 0.125  // ~12.5% de la taille du ring
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
                daysIndicator
            }
            .containerBackground(for: .widget) {
                Color.clear
            }
        }
    }

    // Equivalent de "display: flex; flex-direction: column/row"
    @ViewBuilder
    private func widgetContent(in geometry: GeometryProxy) -> some View {
        let horizontalGap = geometry.size.width * 0.03

        Group {
            if widgetFamily == .systemSmall {
                // flex-direction: column avec distribution verticale
                VStack(alignment: .leading, spacing: 0) {
                    // Stack pour le ring
                    VStack(alignment: .leading, spacing: 0) {
                        batteryRingView(size: ringSize(in: geometry))
                    }

                    // Stack pour le pourcentage
                    VStack(alignment: .leading, spacing: 0) {
                        batteryPercentageView(in: geometry)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                // flex-direction: row
                HStack(alignment: .top, spacing: horizontalGap) {
                    // Colonne principale
                    VStack(alignment: .leading, spacing: 0) {
                        // Stack pour le ring
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // Indicateur de jours - position absolute (top-right)
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

    // Composant: Ring de batterie
    private func batteryRingView(size: CGFloat) -> some View {
        let strokeWidth = ringStrokeWidth(for: size)

        return ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: strokeWidth)

            // Progress circle
            Circle()
                .trim(from: 0, to: batteryProgress)
                .stroke(
                    batteryRingColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            // Battery icon
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: size * 0.35, weight: .regular))
                .foregroundStyle(Color.primary)
                .widgetAccentable()
        }
        .frame(width: size, height: size)
    }

    // Composant: Texte du pourcentage
    private func batteryPercentageView(in geometry: GeometryProxy) -> some View {
        let fontSize = geometry.size.height * 0.40

        return Group {
            if let percentage = entry.percentage {
                Text("\(percentage)%")
                    .font(.system(size: fontSize, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .padding(.top, 10)
            } else {
                Text("--")
                    .font(.system(size: fontSize, weight: .regular, design: .default))
                    .foregroundStyle(.primary.opacity(0.5))
            }
        }
    }

    // Composant: Titre du widget
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
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -2, to: .now))
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -5, to: .now))
    CanvasBatteryEntry(date: .now, percentage: 8, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -10, to: .now))
    CanvasBatteryEntry(date: .now, percentage: nil, lastFullChargeDate: nil)
}

#Preview("Medium", as: .systemMedium) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -3, to: .now))
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -7, to: .now))
    CanvasBatteryEntry(date: .now, percentage: 8, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -14, to: .now))
}

#Preview("Large", as: .systemLarge) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -1, to: .now))
    CanvasBatteryEntry(date: .now, percentage: 38, lastFullChargeDate: Calendar.current.date(byAdding: .day, value: -4, to: .now))
}


