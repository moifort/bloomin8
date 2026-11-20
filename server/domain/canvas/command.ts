import { batteryUpdate, isUpstreamOutdated } from '~/domain/canvas/business-rules'
import * as canvasRepository from '~/domain/canvas/infrastructure/repository'
import { CanvasDate } from '~/domain/canvas/primitives'
import type { Percentage } from '~/domain/canvas/types'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import type { ImageUrl } from '~/domain/image/types'

// A sleeping e-ink device never answers: without a bound, the TCP connect
// hangs for minutes and the GraphQL mutation waiting on it times out client-side.
const WAKE_UP_TIMEOUT_MS = 5_000

export namespace CanvasCommand {
  // Points the device at the server and sets its next pull time. The device
  // only answers while awake (on a manual wake-up, or during its own pull).
  const configureUpstream = async (canvasUrl: CanvasUrl, serverUrl: ServerUrl, cronTime: Date) => {
    const response = await fetch(`${canvasUrl}/upstream/pull_settings`, {
      method: 'PUT',
      signal: AbortSignal.timeout(WAKE_UP_TIMEOUT_MS),
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        upstream_on: true,
        upstream_url: serverUrl,
        token: null,
        cron_time: CanvasDate(cronTime),
      }),
    })
    if (!response.ok) throw new Error(`Failed to configure canvas, ${await response.text()}`)
  }

  export const wakeUp = (canvasUrl: CanvasUrl, serverUrl: ServerUrl) =>
    configureUpstream(canvasUrl, serverUrl, new Date())

  export const recordPulledVia = (host: string) => canvasRepository.savePulledVia(host)

  // Called while the device is still awake after a pull (its /eink_signal): if it
  // pulled through an outdated address, give it the configured server URL, keeping
  // the next pull time already scheduled so no extra pull happens.
  export const repointUpstreamIfOutdated = async (
    canvasUrl: CanvasUrl,
    serverUrl: ServerUrl,
    nextPullAt: Date,
  ) => {
    const pulledVia = await canvasRepository.findPulledVia()
    if (!isUpstreamOutdated({ pulledVia, serverUrl })) return 'up-to-date' as const
    await configureUpstream(canvasUrl, serverUrl, nextPullAt)
    await canvasRepository.savePulledVia(new URL(serverUrl).host)
    return { repointedFrom: pulledVia, to: serverUrl }
  }

  export const saveBattery = async (level: Percentage) => {
    const previous = await canvasRepository.findBattery()
    const updated = batteryUpdate({ previous, level, now: new Date() })
    await canvasRepository.saveBattery(updated)
  }

  // Device-protocol response builders. These format the JSON the BLOOMIN8 device
  // expects when it polls /eink_pull. Kept here because they own the cron-time
  // contract via `CanvasDate`.
  export const showImageResponse = (
    serverUrl: ServerUrl,
    imageUrl: ImageUrl,
    nextCronTime: Date,
  ) => ({
    status: 200,
    type: 'SHOW' as const,
    message: 'Image retrieved successfully',
    data: {
      next_cron_time: CanvasDate(nextCronTime),
      image_url: `${serverUrl}${imageUrl}`,
    },
  })

  export const stopPullingResponse = () => ({
    status: 200,
    message: 'Stopping scheduled pull',
    data: { next_cron_time: null },
  })

  export const deferPullResponse = (nextCronTime: Date, message: string) => ({
    status: 204,
    message,
    data: { next_cron_time: CanvasDate(nextCronTime) },
  })
}
