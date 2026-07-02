import { builder } from '~/domain/shared/graphql/builder'

export const PlaylistStatusEnum = builder.enumType('PlaylistStatus', {
  description: 'Current playback state of the playlist',
  values: {
    in_progress: { value: 'in-progress', description: 'Playlist is actively serving images' },
    paused: { value: 'paused', description: 'Playlist is paused — pulls are deferred' },
  } as const,
})
