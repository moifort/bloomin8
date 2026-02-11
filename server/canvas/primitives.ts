import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  BatteryPercentage as CanvasBatteryPercentageType,
  CanvasDate as CanvasDateType,
} from '~/canvas/types'

export const BatteryPercentage = (value: unknown) => {
  const validatedValue = z
    .preprocess(
      (currentValue) => (typeof currentValue === 'string' ? Number(currentValue) : currentValue),
      z.number().int().min(0).max(100),
    )
    .parse(value)
  return make<CanvasBatteryPercentageType>()(validatedValue)
}

export const CanvasDate = (value: unknown) => {
  const validatedValue = z.date().parse(value)
  const normalizedIsoDate = validatedValue.toISOString().replace(/\.\d{3}Z$/, 'Z')
  return make<CanvasDateType>()(normalizedIsoDate)
}
