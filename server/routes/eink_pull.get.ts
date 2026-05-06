import { CanvasCommand } from '~/domain/canvas/command'
import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'

export default defineEventHandler(async () => {
  const { serverUrl } = config()
  const result = await PlaylistCommand.nextImage()
  if (result === 'playlist-not-found') return CanvasCommand.stopPullingResponse()
  if (result === 'playlist-stopped') return CanvasCommand.stopPullingResponse()
  if (result === 'playlist-empty') return CanvasCommand.stopPullingResponse()
  if (result === 'playlist-paused') return CanvasCommand.deferPullResponse(24)
  if (result === 'image-not-found')
    return CanvasCommand.imageNotFoundResponse(new Date(Date.now() + 24 * 60 * 60 * 1000))
  return CanvasCommand.showImageResponse(serverUrl, result.nextImage.url, result.displayedAt)
})
