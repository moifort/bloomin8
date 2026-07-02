import { GraphQLError } from 'graphql'
import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'
import { QuietHourEnd, QuietHourStart } from '~/domain/playlist/primitives'
import type { QuietHours, Timezone } from '~/domain/playlist/types'
import { builder } from '~/domain/shared/graphql/builder'
import { QuietHoursInput, StartPlaylistInput } from './inputs'
import { PlaylistWakeUpPayloadType } from './types'

const resolveQuietHours = (input: {
  enabled: boolean
  timezone: Timezone
  start?: number | null
  end?: number | null
}): QuietHours => ({
  enabled: input.enabled,
  timezone: input.timezone,
  start: QuietHourStart(input.start ?? 23),
  end: QuietHourEnd(input.end ?? 7),
})

builder.mutationField('startPlaylist', (t) =>
  t.field({
    type: PlaylistWakeUpPayloadType,
    description:
      'Initialize the playlist with the given canvas URL and cron interval, then try to wake the device.',
    args: { input: t.arg({ type: StartPlaylistInput, required: true }) },
    resolve: async (_root, { input }) => {
      const { serverUrl } = config()
      const result = await PlaylistCommand.start(
        serverUrl,
        input.canvasUrl,
        input.cronIntervalInHours,
        input.quietHours ? resolveQuietHours(input.quietHours) : undefined,
      )
      if (result === 'playlist-empty') {
        throw new GraphQLError('Playlist must have at least one image', {
          extensions: { code: 'PLAYLIST_EMPTY' },
        })
      }
      return result
    },
  }),
)

builder.mutationField('updateQuietHours', (t) =>
  t.field({
    type: 'PlaylistId',
    description: 'Change the quiet-hours window of the existing playlist.',
    args: {
      input: t.arg({
        type: QuietHoursInput,
        required: true,
        description: 'New quiet-hours configuration',
      }),
    },
    resolve: async (_root, { input }) => {
      const result = await PlaylistCommand.updateQuietHours(resolveQuietHours(input))
      if (result === 'playlist-not-found') {
        throw new GraphQLError('Playlist not found', { extensions: { code: 'NOT_FOUND' } })
      }
      return result
    },
  }),
)

builder.mutationField('updatePlaylistInterval', (t) =>
  t.field({
    type: 'PlaylistId',
    description: 'Change the cron interval of the existing playlist.',
    args: {
      cronIntervalInHours: t.arg({
        type: 'Hour',
        required: true,
        description: 'New interval between two image displays, in hours',
      }),
    },
    resolve: async (_root, { cronIntervalInHours }) => {
      const result = await PlaylistCommand.updateInterval(cronIntervalInHours)
      if (result === 'playlist-not-found') {
        throw new GraphQLError('Playlist not found', { extensions: { code: 'NOT_FOUND' } })
      }
      return result
    },
  }),
)

builder.mutationField('pausePlaylist', (t) =>
  t.field({
    type: 'PlaylistId',
    description: 'Pause an in-progress playlist so the device defers its next pull.',
    resolve: async () => {
      const result = await PlaylistCommand.pause()
      if (result === 'playlist-not-found') {
        throw new GraphQLError('Playlist not found', { extensions: { code: 'NOT_FOUND' } })
      }
      if (result === 'not-playing') {
        throw new GraphQLError('Playlist is not in progress', {
          extensions: { code: 'NOT_PLAYING' },
        })
      }
      return result
    },
  }),
)

builder.mutationField('resumePlaylist', (t) =>
  t.field({
    type: PlaylistWakeUpPayloadType,
    description: 'Resume a paused playlist and try to wake the device immediately.',
    resolve: async () => {
      const { serverUrl } = config()
      const result = await PlaylistCommand.resume(serverUrl)
      if (result === 'playlist-not-found') {
        throw new GraphQLError('Playlist not found', { extensions: { code: 'NOT_FOUND' } })
      }
      if (result === 'not-paused') {
        throw new GraphQLError('Playlist is not paused', { extensions: { code: 'NOT_PAUSED' } })
      }
      return result
    },
  }),
)
