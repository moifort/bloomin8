import { PlaylistCommand } from '~/domain/playlist/command'
import { Hour } from '~/domain/shared/primitives'

export default defineEventHandler(async (event) => {
  const { cronIntervalInHours } = await readBody(event)
  const result = await PlaylistCommand.updateInterval(Hour(cronIntervalInHours))
  if (result === 'playlist-not-found')
    throw createError({ statusCode: 404, statusMessage: 'Playlist not found' })
  return { status: 200, message: `Playlist ${result} interval updated` }
})
