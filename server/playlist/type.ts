import type { Brand } from 'ts-brand'
import type { ImageId } from '~/images/types'

export type PlaylistId = Brand<string, 'PlaylistId'>
export type PlaylistStatus = 'stop' | 'started' | 'in-progress'
export type Playlist = {
  id: PlaylistId
  status: PlaylistStatus
  availableImagesId: ImageId[]
}
