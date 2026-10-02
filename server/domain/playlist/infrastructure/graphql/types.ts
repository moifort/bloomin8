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
      nextPullDate: t.expose('nextPullDate', {
        type: 'DateTime',
        nullable: true,
        description:
          'When the device is expected to pull next — null until its first pull. A date in the past means the device missed its wake-up.',
      }),
      currentImagePath: t.exposeString('currentImagePath', {
        nullable: true,
        description:
          'Server-relative path of the image currently on display (e.g. /images/<id>_P.jpg) — null before the first pull or once the image was deleted.',
      }),
    }),
  })

export type PlaylistWakeUpPayload = { playlistId: PlaylistId; wokeUp: boolean }

export const PlaylistWakeUpPayloadType = builder
  .objectRef<PlaylistWakeUpPayload>('PlaylistWakeUpPayload')
  .implement({
    description: 'Outcome of a playlist command that tries to wake the device (start, resume)',
    fields: (t) => ({
      playlistId: t.expose('playlistId', {
        type: 'PlaylistId',
        description: 'Identifier of the affected playlist',
      }),
      wokeUp: t.exposeBoolean('wokeUp', {
        description:
          'True if the BLOOMIN8 device acknowledged the wake-up call. False means it was unreachable and will catch up at its next scheduled pull.',
      }),
    }),
  })
