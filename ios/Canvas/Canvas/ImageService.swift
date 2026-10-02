import CanvasGraphQL
import Foundation

struct ImageService {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Final step of an album replacement: drops every image except the new ones.
    /// The server refuses if none of them exists, so the album is never wiped.
    func keepOnly(ids: [String]) async throws {
        _ = try await GraphQLClient.client(for: baseURL)
            .performAsync(CanvasGraphQL.KeepOnlyImagesMutation(ids: ids))
    }

    /// Rollback of a cancelled upload.
    func delete(ids: [String]) async throws {
        _ = try await GraphQLClient.client(for: baseURL)
            .performAsync(CanvasGraphQL.DeleteImagesMutation(ids: ids))
    }
}
