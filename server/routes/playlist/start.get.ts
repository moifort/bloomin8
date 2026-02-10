import { config } from '~/config/index'
import { Playlist } from '~/playlist/index'

export default eventHandler(async () => {
  const { canvasUrl, serverUrl } = config()
  const playlistId = await Playlist.start(canvasUrl, serverUrl)
  return { status: 200, message: `Playlist ${playlistId} started` }
})
