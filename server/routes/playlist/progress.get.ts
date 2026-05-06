import { buildPlaylistProgress } from '~/domain/playlist/read-model'

export default defineEventHandler(async () => {
  const progress = await buildPlaylistProgress()
  if (!progress) return { status: 200, data: 'playlist-not-found' }
  return {
    status: 200,
    data: {
      displayed: progress.displayed,
      total: progress.total,
      status: progress.status,
      cronIntervalInHours: progress.cronIntervalInHours,
    },
  }
})
