import Apollo
import ApolloAPI
import Foundation

enum GraphQLClient {
    /// Build an ApolloClient pointing at `\(baseURL)/graphql`.
    /// Bloomin8 has no auth — the default interceptor chain is enough.
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
                switch result {
                case let .success(graphQLResult):
                    if let errors = graphQLResult.errors, let first = errors.first {
                        continuation.resume(throwing: GraphQLServiceError.server(message: first.message ?? "Unknown error"))
                        return
                    }
                    if let data = graphQLResult.data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: GraphQLServiceError.invalidPayload)
                    }
                case let .failure(error):
                    continuation.resume(throwing: GraphQLServiceError.transport(error))
                }
            }
        }
    }

    /// Bridge Apollo's callback API to async/await for mutations.
    func performAsync<M: GraphQLMutation>(_ mutation: M) async throws -> M.Data {
        try await withCheckedThrowingContinuation { continuation in
            self.perform(mutation: mutation) { result in
                switch result {
                case let .success(graphQLResult):
                    if let errors = graphQLResult.errors, let first = errors.first {
                        continuation.resume(throwing: GraphQLServiceError.server(message: first.message ?? "Unknown error"))
                        return
                    }
                    if let data = graphQLResult.data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: GraphQLServiceError.invalidPayload)
                    }
                case let .failure(error):
                    continuation.resume(throwing: GraphQLServiceError.transport(error))
                }
            }
        }
    }
}
