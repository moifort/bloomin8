import { buildPlaylistProgress } from '~/domain/playlist/read-model'
import { builder } from '~/domain/shared/graphql/builder'
import { PlaylistProgressType } from './types'

builder.queryField('playlistProgress', (t) =>
  t.field({
    type: PlaylistProgressType,
    nullable: true,
    description:
      'Progress of the default playlist. Returns null when no playlist has been started yet.',
    resolve: () => buildPlaylistProgress(),
  }),
)
