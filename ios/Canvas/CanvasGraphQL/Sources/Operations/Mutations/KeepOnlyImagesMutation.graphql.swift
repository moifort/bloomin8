// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class KeepOnlyImagesMutation: GraphQLMutation {
  public static let operationName: String = "KeepOnlyImages"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation KeepOnlyImages($ids: [ImageId!]!) { keepOnlyImages(ids: $ids) }"#
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
      .field("keepOnlyImages", Int.self, arguments: ["ids": .variable("ids")]),
    ] }

    /// Delete every image except the given ones — final step of an album replacement, once the new album is uploaded. Refused with NO_KEPT_IMAGE when none of the ids exists, so a failed upload can never wipe the album. Returns the count of deleted images.
    public var keepOnlyImages: Int { __data["keepOnlyImages"] }
  }
}
