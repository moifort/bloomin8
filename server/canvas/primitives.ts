import { make } from 'ts-brand'
import type { CanvasDate as CanvasDateType } from '~/canvas/types'

export const CanvasDate = (value?: any) => {
  if (!value) throw new Error(`CanvasDate must be a Date, received: ${value}`)
  if (Number.isNaN(value.getTime()))
    throw new Error(`CanvasDate must be a valid Date, received: ${value}`)
  const date = new Date(value).toISOString().replace(/\.\d{3}Z$/, 'Z')
  return make<CanvasDateType>()(date)
}
