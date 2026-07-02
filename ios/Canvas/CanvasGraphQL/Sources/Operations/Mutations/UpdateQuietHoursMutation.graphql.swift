// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateQuietHoursMutation: GraphQLMutation {
  public static let operationName: String = "UpdateQuietHours"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateQuietHours($input: QuietHoursInput!) { updateQuietHours(input: $input) }"#
    ))

  public var input: QuietHoursInput

  public init(input: QuietHoursInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: CanvasGraphQL.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { CanvasGraphQL.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("updateQuietHours", CanvasGraphQL.PlaylistId.self, arguments: ["input": .variable("input")]),
    ] }

    /// Change the quiet-hours window of the existing playlist.
    public var updateQuietHours: CanvasGraphQL.PlaylistId { __data["updateQuietHours"] }
  }
}
