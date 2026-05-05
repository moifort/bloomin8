import { Playlist } from '~/playlist/index'
import { Hour } from '~/playlist/primitives'

export default defineEventHandler(async (event) => {
  const { cronIntervalInHours } = await readBody(event)
  const result = await Playlist.updateInterval(Hour(cronIntervalInHours))
  if (result === 'playlist-not-found')
    throw createError({ statusCode: 404, statusMessage: 'Playlist not found' })
  return { status: 200, message: `Playlist ${result} interval updated` }
})
