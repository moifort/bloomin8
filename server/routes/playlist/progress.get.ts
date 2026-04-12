import { Playlist } from '~/playlist/index'

export default defineEventHandler(async () => {
  const progress = await Playlist.getProgress()
  if (progress === 'playlist-not-found') return { status: 200, data: 'playlist-not-found' }
  return {
    status: 200,
    data: {
      displayed: progress.displayed,
      total: progress.total,
      status: progress.status,
    },
  }
})
