import { Canvas } from '~/canvas/index'
import { config } from '~/config/index'
import { Playlist } from '~/playlist/index'

export default eventHandler(async () => {
  const { cronIntervalInHours, canvasUrl, serverUrl } = config()
  const nextImage = await Playlist.nextImage(canvasUrl, serverUrl, cronIntervalInHours)
  if (nextImage === 'playlist-not-found') return Canvas.stopPulling()
  if (nextImage === 'playlist-stopped') return Canvas.stopPulling()
  if (nextImage === 'playlist-empty') return Canvas.stopPulling()
  if (nextImage === 'image-not-found') return Canvas.imageNotFound()
  return Canvas.getNextImage(serverUrl, nextImage.nextImage.url, nextImage.displayedAt)
})
