import { CanvasCommand } from '~/domain/canvas/command'
import { config } from '~/domain/config'
import { PlaylistQuery } from '~/domain/playlist/query'
import { createLogger } from '~/system/logger'

const log = createLogger('canvas')

// Device feedback is acknowledged and logged, but intentionally not persisted yet.
// The device is still awake here: the moment to repoint an outdated upstream.
export default defineEventHandler(async (event) => {
  const { pull_id, success } = getQuery(event)
  log.info('Device signal received', { pull_id, success })
  const playlist = await PlaylistQuery.findById()
  if (playlist?.nextPullAt) {
    try {
      const outcome = await CanvasCommand.repointUpstreamIfOutdated(
        playlist.canvasUrl,
        config().serverUrl,
        playlist.nextPullAt,
      )
      if (outcome !== 'up-to-date') log.info('Device upstream repointed', outcome)
    } catch (error) {
      log.warn('Could not repoint device upstream, will retry at next pull', error)
    }
  }
  return { status: 200, message: 'Feedback recorded' }
})
