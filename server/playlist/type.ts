import type { Brand } from 'ts-brand'
import type { CanvasUrl, Hour } from '~/config/types'
import type { ImageId } from '~/images/types'

export type PlaylistId = Brand<string, 'PlaylistId'>
export type PlaylistStatus = 'stop' | 'in-progress'

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
