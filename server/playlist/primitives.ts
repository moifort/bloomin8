/** biome-ignore-all lint/suspicious/noExplicitAny: only used for primitives */
import { make } from 'ts-brand'
import type { CanvasUrl as CanvasUrlType, Hour as HourType } from '~/config/types'
import type { PlaylistId as PlaylistIdType } from '~/playlist/type'

export const randomPlaylistId = () => PlaylistId(crypto.randomUUID())
export const PlaylistId = (value?: any) => {
  if (!value) throw new Error(`PlaylistId must be a uuid, received: ${value}`)
  if (typeof value !== 'string') throw new Error(`PlaylistId must be a string, received: ${value}`)
  if (value.length !== 36)
    throw new Error(`PlaylistId must be 36 characters long, received: ${value}`)
  return make<PlaylistIdType>()(value)
}
export const CanvasUrl = make<CanvasUrlType>()
export const Hour = (value?: any) => {
  if (typeof value === 'number') return make<HourType>()(value)
  if (typeof value === 'string') return make<HourType>()(Number(value))
  throw new Error(`Hour must be a number, received: ${value}`)
}
