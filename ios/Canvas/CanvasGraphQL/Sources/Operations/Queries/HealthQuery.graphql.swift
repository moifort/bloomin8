// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class HealthQuery: GraphQLQuery {
  public static let operationName: String = "Health"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query Health { health }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("health", String.self),
    ] }

    /// Liveness probe — always returns "ok" when the GraphQL server is up.
    public var health: String { __data["health"] }
  }
}
