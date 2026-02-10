import { CanvasDate } from '~/canvas/primitives'
import type { CanvasUrl, ServerUrl } from '~/config/types'
import type { ImageUrl } from '~/images/types'

export namespace Canvas {
  export const wakeUp = async (canvasUrl: CanvasUrl, serverUrl: ServerUrl) =>
    configure(canvasUrl, serverUrl)

  const configure = async (canvasUrl: CanvasUrl, serverUrl: ServerUrl) => {
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

  export const getNextImage = async (
    serverUrl: ServerUrl,
    imageUrl: ImageUrl,
    nextCronTime: Date,
  ) => {
    return {
      status: 200,
      type: 'SHOW',
      message: 'Image retrieved successfully',
      data: {
        next_cron_time: CanvasDate(nextCronTime),
        image_url: `${serverUrl}${imageUrl}`,
      },
    }
  }

  export const imageNotFound = async () => ({
    status: 204,
    message: 'No image available',
    data: {
      next_cron_time: '2025-11-01T09:00:00Z',
    },
  })

  export const stopPulling = async () => ({
    status: 200,
    message: 'Stopping scheduled pull',
    data: { next_cron_time: null },
  })
}
