import { make } from 'ts-brand'
import { z } from 'zod'
import type { CanvasDate as CanvasDateType, Percentage as PercentageType } from '~/canvas/types'

export const Percentage = (value: unknown) => {
  const validatedValue = z
    .preprocess(
      (currentValue) => (typeof currentValue === 'string' ? Number(currentValue) : currentValue),
      z.number().int().min(0).max(100),
    )
    .parse(value)
  return make<PercentageType>()(validatedValue)
}

export const CanvasDate = (value: unknown) => {
  const validatedValue = z.date().parse(value)
  const normalizedIsoDate = validatedValue.toISOString().replace(/\.\d{3}Z$/, 'Z')
  return make<CanvasDateType>()(normalizedIsoDate)
}
