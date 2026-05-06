import type { PlaylistProgress } from '~/domain/playlist/read-model'
import type { PlaylistId } from '~/domain/playlist/types'
import { builder } from '~/domain/shared/graphql/builder'
import { PlaylistStatusEnum } from './enums'

export const PlaylistProgressType = builder
  .objectRef<PlaylistProgress>('PlaylistProgress')
  .implement({
    description: 'Snapshot of how many images have been displayed during the current cycle',
    fields: (t) => ({
      displayed: t.exposeInt('displayed', {
        description: 'Number of images already shown in the current cycle',
      }),
      total: t.exposeInt('total', { description: 'Total number of images uploaded' }),
      status: t.expose('status', {
        type: PlaylistStatusEnum,
        description: 'Current playlist status',
      }),
      cronIntervalInHours: t.expose('cronIntervalInHours', {
        type: 'Hour',
        description: 'Interval between two image displays, in hours',
      }),
    }),
  })

export type PlaylistResumePayload = { playlistId: PlaylistId; wokeUp: boolean }

export const PlaylistResumePayloadType = builder
  .objectRef<PlaylistResumePayload>('PlaylistResumePayload')
  .implement({
    description: 'Outcome of resuming a paused playlist',
    fields: (t) => ({
      playlistId: t.expose('playlistId', {
        type: 'PlaylistId',
        description: 'Identifier of the resumed playlist',
      }),
      wokeUp: t.exposeBoolean('wokeUp', {
        description:
          'True if the BLOOMIN8 device acknowledged the wake-up call. False means it was unreachable and will catch up at its next scheduled pull.',
      }),
    }),
  })
