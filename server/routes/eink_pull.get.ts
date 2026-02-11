import { Canvas } from '~/canvas/index'
import { config } from '~/config/index'
import { Playlist } from '~/playlist/index'

export default defineEventHandler(async () => {
  const { serverUrl } = config()
  const nextImage = await Playlist.nextImage()
  if (nextImage === 'playlist-not-found') return Canvas.stopPulling()
  if (nextImage === 'playlist-stopped') return Canvas.stopPulling()
  if (nextImage === 'playlist-empty') return Canvas.stopPulling()
  if (nextImage === 'image-not-found') return Canvas.imageNotFound()
  return Canvas.getNextImage(serverUrl, nextImage.nextImage.url, nextImage.displayedAt)
})
