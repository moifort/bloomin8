import Apollo
import ApolloAPI
import CanvasShared
import Foundation

enum GraphQLClient {
    /// Covers the server's own 5 s wake-up timeout on start/resume.
    static let requestTimeout: TimeInterval = 15

    static func client(for baseURL: URL) -> ApolloClient {
        CanvasGraphQLClient.make(baseURL: baseURL, timeout: requestTimeout)
    }
}

/// Errors surfaced by GraphQL services. Keeps existing localized messages so
/// the UI strings (formerly produced by REST services) stay unchanged.
enum GraphQLServiceError: LocalizedError {
    case transport(Error)
    case server(message: String)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case let .transport(error):
            return error.localizedDescription
        case let .server(message):
            return String(localized: "Serveur: \(message)")
        case .invalidPayload:
            return String(localized: "Réponse GraphQL invalide.")
        }
    }
}

extension ApolloClient {
    /// Bridge Apollo's callback API to async/await for queries.
    func fetchAsync<Q: GraphQLQuery>(_ query: Q) async throws -> Q.Data {
        try await withCheckedThrowingContinuation { continuation in
            self.fetch(query: query, cachePolicy: .fetchIgnoringCacheCompletely) { result in
                continuation.resume(with: Self.unwrap(result))
            }
        }
    }

    /// Bridge Apollo's callback API to async/await for mutations.
    func performAsync<M: GraphQLMutation>(_ mutation: M) async throws -> M.Data {
        try await withCheckedThrowingContinuation { continuation in
            self.perform(mutation: mutation) { result in
                continuation.resume(with: Self.unwrap(result))
            }
        }
    }

    private static func unwrap<Data>(_ result: Result<GraphQLResult<Data>, Error>) -> Result<Data, Error> {
        switch result {
        case let .success(graphQLResult):
            if let first = graphQLResult.errors?.first {
                return .failure(GraphQLServiceError.server(message: first.message ?? "Unknown error"))
            }
            guard let data = graphQLResult.data else {
                return .failure(GraphQLServiceError.invalidPayload)
            }
            return .success(data)
        case let .failure(error):
            return .failure(GraphQLServiceError.transport(error))
        }
    }
}
