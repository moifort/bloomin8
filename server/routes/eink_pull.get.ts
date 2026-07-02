import { CanvasCommand } from '~/domain/canvas/command'
import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'
import { PlaylistQuery } from '~/domain/playlist/query'

export default defineEventHandler(async () => {
  const { serverUrl } = config()
  const result = await PlaylistCommand.nextImage()
  if (result === 'playlist-not-found') return CanvasCommand.stopPullingResponse()
  if (result === 'playlist-empty') return CanvasCommand.stopPullingResponse()
  if (result === 'playlist-paused') {
    const playlist = await PlaylistQuery.findById()
    return CanvasCommand.deferPullResponse(playlist?.cronIntervalInHours ?? 24)
  }
  return CanvasCommand.showImageResponse(serverUrl, result.nextImage.url, result.displayedAt)
})
