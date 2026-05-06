import type { Playlist, PlaylistId } from '~/domain/playlist/types'

const bucket = () => useStorage<Playlist>('playlist')

export const findById = async (id: PlaylistId) => {
  const playlist = await bucket().getItem(id)
  return playlist ?? null
}

export const save = async (playlist: Playlist) => {
  await bucket().setItem(playlist.id, playlist)
}
