// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateCanvasUrlMutation: GraphQLMutation {
  public static let operationName: String = "UpdateCanvasUrl"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateCanvasUrl($canvasUrl: CanvasUrl!) { updateCanvasUrl(canvasUrl: $canvasUrl) }"#
    ))

  public var canvasUrl: CanvasUrl

  public init(canvasUrl: CanvasUrl) {
    self.canvasUrl = canvasUrl
  }

  public var __variables: Variables? { ["canvasUrl": canvasUrl] }

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("updateCanvasUrl", CanvasGraphQL.PlaylistId.self, arguments: ["canvasUrl": .variable("canvasUrl")]),
    ] }

    /// Change the address the server uses to wake the Canvas up (start/resume) of the existing playlist.
    public var updateCanvasUrl: CanvasGraphQL.PlaylistId { __data["updateCanvasUrl"] }
  }
}
