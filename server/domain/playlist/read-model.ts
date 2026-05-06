import * as imageRepository from '~/domain/image/infrastructure/repository'
import * as playlistRepository from '~/domain/playlist/infrastructure/repository'
import { DEFAULT_PLAYLIST_ID } from '~/domain/playlist/primitives'
import type { PlaylistId, PlaylistStatus } from '~/domain/playlist/types'
import type { Hour } from '~/domain/shared/types'

export type PlaylistProgress = {
  displayed: number
  total: number
  status: PlaylistStatus
  cronIntervalInHours: Hour
}

export const buildPlaylistProgress = async (
  playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
): Promise<PlaylistProgress | null> => {
  const playlist = await playlistRepository.findById(playlistId)
  if (!playlist) return null
  const allImagesId = await imageRepository.findAllIds()
  const total = allImagesId.length
  const remaining = playlist.availableImagesId.length
  return {
    displayed: total - remaining,
    total,
    status: playlist.status,
    cronIntervalInHours: playlist.cronIntervalInHours,
  }
}
