import { make } from 'ts-brand'
import { z } from 'zod'
import type { CanvasUrl as CanvasUrlType, Hour as HourType } from '~/config/types'
import type {
  PlaylistId as PlaylistIdType,
  QuietHourEnd as QuietHourEndType,
  QuietHourStart as QuietHourStartType,
  Timezone as TimezoneType,
} from '~/playlist/type'

export const randomPlaylistId = () => PlaylistId(crypto.randomUUID())

export const PlaylistId = (value: unknown) => {
  const validatedValue = z.uuid().parse(value)
  return make<PlaylistIdType>()(validatedValue)
}

export const CanvasUrl = (value: unknown) => {
  const validatedValue = z.url().parse(value)
  return make<CanvasUrlType>()(validatedValue)
}

export const Hour = (value: unknown) => {
  const validatedValue = z
    .preprocess((value) => (typeof value === 'string' ? Number(value) : value), z.number())
    .parse(value)
  return make<HourType>()(validatedValue)
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
