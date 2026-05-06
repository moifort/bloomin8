import { batteryUpdate } from '~/domain/canvas/business-rules'
import * as canvasRepository from '~/domain/canvas/infrastructure/repository'
import { CanvasDate } from '~/domain/canvas/primitives'
import type { Percentage } from '~/domain/canvas/types'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import type { ImageUrl } from '~/domain/image/types'

export namespace CanvasCommand {
  export const wakeUp = async (canvasUrl: CanvasUrl, serverUrl: ServerUrl) => {
    const response = await fetch(`${canvasUrl}/upstream/pull_settings`, {
      method: 'PUT',
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

  export const imageNotFoundResponse = (nextCronTime: Date) => ({
    status: 204,
    message: 'No image available',
    data: { next_cron_time: CanvasDate(nextCronTime) },
  })

  export const stopPullingResponse = () => ({
    status: 200,
    message: 'Stopping scheduled pull',
    data: { next_cron_time: null },
  })

  export const deferPullResponse = (hours = 24) => ({
    status: 204,
    message: 'Playlist paused',
    data: {
      next_cron_time: CanvasDate(new Date(Date.now() + hours * 60 * 60 * 1000)),
    },
  })
}
