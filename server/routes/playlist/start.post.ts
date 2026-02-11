import { config } from '~/config/index'
import { Playlist } from '~/playlist/index'
import { CanvasUrl, Hour } from '~/playlist/primitives'

export default eventHandler(async (event) => {
  const { serverUrl } = config()
  const { canvasUrl, cronIntervalInHours } = await readBody(event)
  const playlistId = await Playlist.start(
    serverUrl,
    CanvasUrl(canvasUrl),
    Hour(cronIntervalInHours),
  )
  if (playlistId === 'playlist-empty')
    throw createError({ statusCode: 400, statusMessage: 'Playlist must have at least one image' })
  return { status: 200, message: `Playlist ${playlistId} started` }
})
