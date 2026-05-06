// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public protocol SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == CanvasGraphQL.SchemaMetadata {}

public protocol InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == CanvasGraphQL.SchemaMetadata {}

public protocol MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == CanvasGraphQL.SchemaMetadata {}

public protocol MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == CanvasGraphQL.SchemaMetadata {}

public enum SchemaMetadata: ApolloAPI.SchemaMetadata {
  public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

  public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
    switch typename {
    case "BatteryInfo": return CanvasGraphQL.Objects.BatteryInfo
    case "Mutation": return CanvasGraphQL.Objects.Mutation
    case "PlaylistProgress": return CanvasGraphQL.Objects.PlaylistProgress
    case "PlaylistResumePayload": return CanvasGraphQL.Objects.PlaylistResumePayload
    case "Query": return CanvasGraphQL.Objects.Query
    default: return nil
    }
  }
}

public enum Objects {}
public enum Interfaces {}
public enum Unions {}
