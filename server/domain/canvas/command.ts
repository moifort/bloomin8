import { batteryUpdate } from '~/domain/canvas/business-rules'
import * as canvasRepository from '~/domain/canvas/infrastructure/repository'
import { CanvasDate } from '~/domain/canvas/primitives'
import type { Percentage } from '~/domain/canvas/types'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import type { ImageUrl } from '~/domain/image/types'

// A sleeping e-ink device never answers: without a bound, the TCP connect
// hangs for minutes and the GraphQL mutation waiting on it times out client-side.
const WAKE_UP_TIMEOUT_MS = 5_000

export namespace CanvasCommand {
  export const wakeUp = async (canvasUrl: CanvasUrl, serverUrl: ServerUrl) => {
    const response = await fetch(`${canvasUrl}/upstream/pull_settings`, {
      method: 'PUT',
      signal: AbortSignal.timeout(WAKE_UP_TIMEOUT_MS),
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        upstream_on: true,
        upstream_url: serverUrl,
        token: null,
        cron_time: CanvasDate(new Date()),
      }),
    })
    if (!response.ok) throw new Error(`Failed to configure canvas, ${await response.text()}`)
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
