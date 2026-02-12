import SwiftUI
import WidgetKit
import UIKit

private enum CanvasWidgetStore {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let batteryPercentageKey = "canvas.battery.percentage"
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
    struct LegacyPayload: Decodable {
        let percentage: Int
    }

    enum Payload: Decodable {
        case percentage(Int)
        case unavailable

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let rawPercentage = try? container.decode(Int.self) {
                self = .percentage(rawPercentage)
                return
            }

            if let rawStatus = try? container.decode(String.self), rawStatus == "battery-unavailable" {
                self = .unavailable
                return
            }

            if let legacyPayload = try? container.decode(LegacyPayload.self) {
                self = .percentage(legacyPayload.percentage)
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
    let backgroundImage: UIImage?
}

private struct CanvasBatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> CanvasBatteryEntry {
        CanvasBatteryEntry(date: Date(), percentage: 72, backgroundImage: nil)
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
        let percentage = await resolveBatteryPercentage()
        let backgroundImage = resolveBackgroundImage(displaySize: displaySize)
        return CanvasBatteryEntry(date: Date(), percentage: percentage, backgroundImage: backgroundImage)
    }

    private func resolveBatteryPercentage() async -> Int? {
        if let cachedBattery = readCachedBatteryPercentage() {
            return cachedBattery
        }

        guard let fetchedBattery = await fetchBatteryPercentage() else {
            return nil
        }

        persistBatteryPercentage(fetchedBattery)
        return fetchedBattery
    }

    private func fetchBatteryPercentage() async -> Int? {
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
        case let .percentage(value):
            return value
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

    private var ringSize: CGFloat {
        switch widgetFamily {
        case .systemSmall:
            return 96
        case .systemMedium:
            return 110
        case .systemLarge:
            return 130
        default:
            return 96
        }
    }

    private var ringStrokeWidth: CGFloat {
        switch widgetFamily {
        case .systemSmall:
            return 11
        case .systemMedium:
            return 13
        case .systemLarge:
            return 15
        default:
            return 11
        }
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
            return Color(red: 0.20, green: 0.84, blue: 0.35)
        }
    }

    var body: some View {
        if widgetFamily == .systemMedium || widgetFamily == .systemLarge {
            // Horizontal layout for medium and large widgets
            HStack(spacing: 20) {
                singleRingCard
                
                if let percentage = entry.percentage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Canvas Battery")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .widgetAccentable()
                        
                        Text("\(percentage)%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            .widgetAccentable()
                        
                        if widgetFamily == .systemLarge {
                            Spacer()
                            Text("Last updated: \(entry.date.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .containerBackground(for: .widget) {
                // Liquid Glass transparent background
                Color.clear
            }
        } else {
            // Original small widget layout
            ZStack {
                singleRingCard
            }
            .containerBackground(for: .widget) {
                // Liquid Glass transparent background
                Color.clear
            }
        }
    }

    private var singleRingCard: some View {
        ZStack {
            // Cercle de fond avec un effet de glass
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: ringStrokeWidth)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            // Cercle de progression
            Circle()
                .trim(from: 0, to: batteryProgress)
                .stroke(
                    batteryRingColor,
                    style: StrokeStyle(lineWidth: ringStrokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: batteryRingColor.opacity(0.5), radius: 4, x: 0, y: 0)
                .widgetAccentable() // Makes the progress ring accent in tinted mode

            // Icône avec une ombre pour plus de visibilité
            Image(systemName: "person.crop.artframe")
                .font(.system(size: ringSize * 0.34, weight: .medium))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .widgetAccentable() // Makes the icon accent in tinted mode
        }
        .frame(width: ringSize, height: ringSize)
        .padding(26)
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
        .containerBackgroundRemovable(true) // Active la transparence Liquid Glass
    }
}

#Preview("Small", as: .systemSmall) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: 38, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: 8, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: nil, backgroundImage: nil)
}
#Preview("Medium", as: .systemMedium) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: 38, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: 8, backgroundImage: nil)
}

#Preview("Large", as: .systemLarge) {
    CanvasBatteryWidget()
} timeline: {
    CanvasBatteryEntry(date: .now, percentage: 78, backgroundImage: nil)
    CanvasBatteryEntry(date: .now, percentage: 38, backgroundImage: nil)
}

