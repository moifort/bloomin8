// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Current playback state of the playlist
public enum PlaylistStatus: String, EnumType {
  /// Playlist is actively serving images
  case inProgress = "in_progress"
  /// Playlist is paused — pulls are deferred
  case paused = "paused"
  /// Playlist exists but device pulling is stopped
  case stop = "stop"
}
