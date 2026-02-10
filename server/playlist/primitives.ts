/** biome-ignore-all lint/suspicious/noExplicitAny: only used for primitives */
import { make } from 'ts-brand'
import type { PlaylistId as PlaylistIdType } from '~/playlist/type'

export const randomPlaylistId = () => PlaylistId(crypto.randomUUID())
export const PlaylistId = (value?: any) => {
  if (!value) throw new Error(`PlaylistId must be a uuid, received: ${value}`)
  if (typeof value !== 'string') throw new Error(`PlaylistId must be a string, received: ${value}`)
  if (value.length !== 36)
    throw new Error(`PlaylistId must be 36 characters long, received: ${value}`)
  return make<PlaylistIdType>()(value)
}
