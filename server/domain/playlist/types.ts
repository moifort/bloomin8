import type { Brand } from 'ts-brand'
import type { CanvasUrl } from '~/domain/config/types'
import type { ImageId } from '~/domain/image/types'
import type { Hour } from '~/domain/shared/types'

export type PlaylistId = Brand<string, 'PlaylistId'>
export type PlaylistStatus = 'stop' | 'in-progress' | 'paused'

export type Timezone = Brand<string, 'Timezone'>
export type QuietHourStart = Brand<number, 'QuietHourStart'>
export type QuietHourEnd = Brand<number, 'QuietHourEnd'>

export type QuietHours = {
  enabled: boolean
  timezone: Timezone
  start: QuietHourStart
  end: QuietHourEnd
}

export type Playlist = {
  id: PlaylistId
  status: PlaylistStatus
  canvasUrl: CanvasUrl
  cronIntervalInHours: Hour
  availableImagesId: ImageId[]
  quietHours?: QuietHours
}
