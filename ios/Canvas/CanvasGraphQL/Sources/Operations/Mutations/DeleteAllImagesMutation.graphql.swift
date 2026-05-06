// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteAllImagesMutation: GraphQLMutation {
  public static let operationName: String = "DeleteAllImages"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteAllImages { deleteAllImages }"#
    ))

  public init() {}

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("deleteAllImages", Int.self),
    ] }

    /// Delete every uploaded image. Returns the count of deleted entries.
    public var deleteAllImages: Int { __data["deleteAllImages"] }
  }
}
