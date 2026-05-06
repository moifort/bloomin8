import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'

export default defineEventHandler(async () => {
  const { serverUrl } = config()
  const result = await PlaylistCommand.resume(serverUrl)
  if (result === 'playlist-not-found')
    throw createError({ statusCode: 404, statusMessage: 'Playlist not found' })
  if (result === 'not-paused')
    throw createError({ statusCode: 409, statusMessage: 'Playlist is not paused' })
  return {
    status: 200,
    message: `Playlist ${result.playlistId} resumed`,
    data: { wokeUp: result.wokeUp },
  }
})
