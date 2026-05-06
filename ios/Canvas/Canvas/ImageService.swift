import CanvasGraphQL
import Foundation

struct ImageService {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func deleteAll() async throws -> String {
        _ = try await GraphQLClient.client(for: baseURL).performAsync(CanvasGraphQL.DeleteAllImagesMutation())
        return String(localized: "Photos supprimées.")
    }
}
