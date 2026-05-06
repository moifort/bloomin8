import { config } from '~/domain/config'
import { CanvasUrl } from '~/domain/config/primitives'
import { PlaylistCommand } from '~/domain/playlist/command'
import { QuietHourEnd, QuietHourStart, Timezone } from '~/domain/playlist/primitives'
import { Hour } from '~/domain/shared/primitives'

export default defineEventHandler(async (event) => {
  const { serverUrl } = config()
  const { canvasUrl, cronIntervalInHours, quietHours } = await readBody(event)

  const resolvedQuietHours = quietHours?.enabled
    ? {
        enabled: true as const,
        timezone: Timezone(quietHours.timezone),
        start: QuietHourStart(23),
        end: QuietHourEnd(7),
      }
    : undefined

  const playlistId = await PlaylistCommand.start(
    serverUrl,
    CanvasUrl(canvasUrl),
    Hour(cronIntervalInHours),
    resolvedQuietHours,
  )
  if (playlistId === 'playlist-empty')
    throw createError({ statusCode: 400, statusMessage: 'Playlist must have at least one image' })
  return { status: 200, message: `Playlist ${playlistId} started` }
})
