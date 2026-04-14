import { Playlist } from '~/playlist/index'

export default defineEventHandler(async () => {
  const result = await Playlist.pause()
  if (result === 'playlist-not-found')
    throw createError({ statusCode: 404, statusMessage: 'Playlist not found' })
  if (result === 'not-playing')
    throw createError({ statusCode: 409, statusMessage: 'Playlist is not in progress' })
  return { status: 200, message: `Playlist ${result} paused` }
})
