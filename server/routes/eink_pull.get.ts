export default eventHandler(async () => {
  return {
    status: 200,
    type: 'SHOW',
    message: 'Image retrieved successfully',
    data: {
      next_cron_time: '2025-11-01T09:00:00Z',
      image_url: 'https://your-upstream.com/images/photo_P.jpg',
    },
  }
})
