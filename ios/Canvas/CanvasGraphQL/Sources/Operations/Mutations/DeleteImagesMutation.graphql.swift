// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteImagesMutation: GraphQLMutation {
  public static let operationName: String = "DeleteImages"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteImages($ids: [ImageId!]!) { deleteImages(ids: $ids) }"#
    ))

  public var ids: [ImageId]

  public init(ids: [ImageId]) {
    self.ids = ids
  }

  public var __variables: Variables? { ["ids": ids] }

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("deleteImages", Int.self, arguments: ["ids": .variable("ids")]),
    ] }

    /// Delete the given images — used to roll back a cancelled upload. Unknown ids are ignored. Returns the count of deleted images.
    public var deleteImages: Int { __data["deleteImages"] }
  }
}
