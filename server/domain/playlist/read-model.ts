import * as imageRepository from '~/domain/image/infrastructure/repository'
import { countDisplayed } from '~/domain/playlist/business-rules'
import * as playlistRepository from '~/domain/playlist/infrastructure/repository'
import { DEFAULT_PLAYLIST_ID } from '~/domain/playlist/primitives'
import type { PlaylistId, PlaylistStatus } from '~/domain/playlist/types'
import type { Hour } from '~/domain/shared/types'

export type PlaylistProgress = {
  displayed: number
  total: number
  status: PlaylistStatus
  cronIntervalInHours: Hour
  nextPullDate: Date | null
  currentImagePath: string | null
}

export const buildPlaylistProgress = async (
  playlistId: PlaylistId = DEFAULT_PLAYLIST_ID,
): Promise<PlaylistProgress | null> => {
  const playlist = await playlistRepository.findById(playlistId)
  if (!playlist) return null
  const allImagesId = await imageRepository.findAllIds()
  const currentImage = playlist.lastImageId
    ? await imageRepository.findById(playlist.lastImageId)
    : null
  return {
    displayed: countDisplayed(allImagesId, playlist.shownImagesId),
    total: allImagesId.length,
    status: playlist.status,
    cronIntervalInHours: playlist.cronIntervalInHours,
    nextPullDate: playlist.nextPullAt ?? null,
    currentImagePath: currentImage?.url ?? null,
  }
}
