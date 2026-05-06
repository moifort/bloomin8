// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdatePlaylistIntervalMutation: GraphQLMutation {
  public static let operationName: String = "UpdatePlaylistInterval"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdatePlaylistInterval($cronIntervalInHours: Hour!) { updatePlaylistInterval(cronIntervalInHours: $cronIntervalInHours) }"#
    ))

  public var cronIntervalInHours: Hour

  public init(cronIntervalInHours: Hour) {
    self.cronIntervalInHours = cronIntervalInHours
  }

  public var __variables: Variables? { ["cronIntervalInHours": cronIntervalInHours] }

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("updatePlaylistInterval", CanvasGraphQL.PlaylistId.self, arguments: ["cronIntervalInHours": .variable("cronIntervalInHours")]),
    ] }

    /// Change the cron interval of the existing playlist.
    public var updatePlaylistInterval: CanvasGraphQL.PlaylistId { __data["updatePlaylistInterval"] }
  }
}
