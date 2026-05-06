import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  PlaylistId as PlaylistIdType,
  QuietHourEnd as QuietHourEndType,
  QuietHourStart as QuietHourStartType,
  Timezone as TimezoneType,
} from '~/domain/playlist/types'

export const randomPlaylistId = () => PlaylistId(crypto.randomUUID())

export const PlaylistId = (value: unknown) => {
  const validatedValue = z.uuid().parse(value)
  return make<PlaylistIdType>()(validatedValue)
}

export const Timezone = (value: unknown) => {
  const validatedValue = z
    .string()
    .refine((v) => Intl.supportedValuesOf('timeZone').includes(v), {
      message: 'Invalid IANA timezone identifier',
    })
    .parse(value)
  return make<TimezoneType>()(validatedValue)
}

export const QuietHourStart = (value: unknown) => {
  const validatedValue = z.number().int().min(0).max(23).parse(value)
  return make<QuietHourStartType>()(validatedValue)
}

export const QuietHourEnd = (value: unknown) => {
  const validatedValue = z.number().int().min(0).max(23).parse(value)
  return make<QuietHourEndType>()(validatedValue)
}

export const DEFAULT_PLAYLIST_ID = PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4')
