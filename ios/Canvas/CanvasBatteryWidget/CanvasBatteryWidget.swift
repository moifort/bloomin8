import SwiftUI
import WidgetKit

private enum CanvasWidgetStore {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let batteryPercentageKey = "canvas.battery.percentage"
    static let defaultServerURL = "http://192.168.0.165:3000"
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
}

private struct CanvasBatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> CanvasBatteryEntry {
        CanvasBatteryEntry(date: Date(), percentage: 72)
    }

    func getSnapshot(in context: Context, completion: @escaping (CanvasBatteryEntry) -> Void) {
        Task {
            completion(CanvasBatteryEntry(date: Date(), percentage: await resolveBatteryPercentage()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CanvasBatteryEntry>) -> Void) {
        Task {
            let entry = CanvasBatteryEntry(date: Date(), percentage: await resolveBatteryPercentage())
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
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
}

private struct CanvasBatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CanvasBatteryProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .accessoryRectangular:
            accessoryBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Canvas", systemImage: batteryIconName)
                .font(.subheadline)

            Text(batteryText)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.8)

            if let percentage = entry.percentage {
                ProgressView(value: Double(percentage), total: 100)
                    .tint(progressTintColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetBackground()
    }

    private var mediumBody: some View {
        HStack(spacing: 12) {
            Image(systemName: batteryIconName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(progressTintColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("Batterie Canvas")
                    .font(.headline)
                Text(batteryText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                if let percentage = entry.percentage {
                    ProgressView(value: Double(percentage), total: 100)
                        .tint(progressTintColor)
                } else {
                    Text("Indisponible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground()
    }

    private var accessoryBody: some View {
        HStack(spacing: 8) {
            Image(systemName: batteryIconName)
                .foregroundStyle(progressTintColor)
            Text("Canvas \(batteryText)")
                .lineLimit(1)
        }
    }

    private var batteryText: String {
        guard let percentage = entry.percentage else {
            return "--"
        }
        return "\(percentage)%"
    }

    private var batteryIconName: String {
        guard let percentage = entry.percentage else {
            return "battery.0"
        }

        switch percentage {
        case 0 ... 10:
            return "battery.0"
        case 11 ... 35:
            return "battery.25"
        case 36 ... 60:
            return "battery.50"
        case 61 ... 85:
            return "battery.75"
        default:
            return "battery.100"
        }
    }

    private var progressTintColor: Color {
        guard let percentage = entry.percentage else {
            return .secondary
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
}

private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            padding()
                .background(Color(.systemBackground))
        }
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
