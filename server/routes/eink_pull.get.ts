import { CanvasCommand } from '~/domain/canvas/command'
import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'

export default defineEventHandler(async (event) => {
  const { serverUrl } = config()
  // Which address the device used: compared with serverUrl at /eink_signal.
  const host = getRequestHost(event)
  if (host) await CanvasCommand.recordPulledVia(host)
  const result = await PlaylistCommand.nextImage()
  if (result === 'playlist-not-found') return CanvasCommand.stopPullingResponse()
  if (result.kind === 'show') {
    return CanvasCommand.showImageResponse(serverUrl, result.image.url, result.nextPullAt)
  }
  // An empty playlist is transient (the app deletes everything before re-uploading
  // an album): keep the device polling instead of stopping it for good, since a
  // stopped device only restarts after a manual wake-up.
  return CanvasCommand.deferPullResponse(
    result.nextPullAt,
    result.kind === 'paused' ? 'Playlist paused' : 'Playlist empty',
  )
})
