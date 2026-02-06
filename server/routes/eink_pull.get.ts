import { pullEink } from '../application/pull-eink'

export default eventHandler(async (event) => {
  const result = await pullEink()
  const origin = getRequestURL(event).origin

  if (result.kind === 'empty') {
    return {
      status: 204,
      message: 'No image available',
      data: {
        next_cron_time: result.nextCronTime,
      },
    }
  }

  const imageUrl = `${origin}/images/${encodeURIComponent(result.photo.file)}`

  return {
    status: 200,
    type: 'SHOW',
    message: 'Image retrieved successfully',
    data: {
      next_cron_time: result.nextCronTime,
      image_url: imageUrl,
    },
  }
})
