import type { ImageId } from '~/domain/image/types'
import type { Playlist, PlaylistId } from '~/domain/playlist/types'

// Playlists saved before `shownImagesId` stored the remaining ids instead.
// `PlaylistCommand.migrateLegacyCycle` converts them at startup.
type StoredPlaylist = Omit<Playlist, 'shownImagesId'> & {
  shownImagesId?: ImageId[]
  availableImagesId?: ImageId[]
}

const bucket = () => useStorage<StoredPlaylist>('playlist')

export const findById = async (id: PlaylistId): Promise<Playlist | null> => {
  const stored = await bucket().getItem(id)
  if (!stored) return null
  const { availableImagesId: _legacy, shownImagesId, nextPullAt, ...playlist } = stored
  return {
    ...playlist,
    shownImagesId: shownImagesId ?? [],
    // JSON storage hands dates back as strings.
    nextPullAt: nextPullAt ? new Date(nextPullAt) : undefined,
  }
}

export const findLegacyRemainingImagesId = async (id: PlaylistId) => {
  const stored = await bucket().getItem(id)
  return stored && !stored.shownImagesId ? (stored.availableImagesId ?? null) : null
}

export const save = async (playlist: Playlist) => {
  await bucket().setItem(playlist.id, playlist)
}
