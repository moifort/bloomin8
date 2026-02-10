import { make } from 'ts-brand'
import type {
  CanvasUrl as CanvasUrlType,
  Hour as HourType,
  ServerUrl as ServerUrlType,
} from '~/config/types'

export const CanvasUrl = make<CanvasUrlType>()
export const ServerUrl = make<ServerUrlType>()

export const Hour = (value?: any) => {
  if (typeof value === 'number') return make<HourType>()(value)
  if (typeof value === 'string') return make<HourType>()(Number(value))
  throw new Error(`Hour must be a number, received: ${value}`)
}
