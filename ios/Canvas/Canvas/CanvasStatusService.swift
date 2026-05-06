import CanvasGraphQL
import Foundation

struct CanvasStatusService {
    struct BatteryData {
        let percentage: Int
        let lastFullChargeDate: String?
        let lastPullDate: String?
    }

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func getBatteryReport() async throws -> Int? {
        try await getBatteryData()?.percentage
    }

    func getBatteryData() async throws -> BatteryData? {
        let result = try await GraphQLClient.client(for: baseURL).fetchAsync(CanvasGraphQL.CanvasBatteryQuery())
        guard let battery = result.canvasBattery else { return nil }
        guard let percentage = Int(battery.percentage) else { return nil }
        return BatteryData(
            percentage: percentage,
            lastFullChargeDate: battery.lastFullChargeDate,
            lastPullDate: battery.lastPullDate
        )
    }
}
