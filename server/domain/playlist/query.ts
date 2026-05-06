import * as playlistRepository from '~/domain/playlist/infrastructure/repository'
import { DEFAULT_PLAYLIST_ID } from '~/domain/playlist/primitives'
import type { PlaylistId } from '~/domain/playlist/types'

export namespace PlaylistQuery {
  export const findById = (id: PlaylistId = DEFAULT_PLAYLIST_ID) => playlistRepository.findById(id)
}
