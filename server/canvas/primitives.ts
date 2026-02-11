import { make } from 'ts-brand'
import { z } from 'zod'
import type { CanvasDate as CanvasDateType } from '~/canvas/types'

export const CanvasDate = (value: unknown) => {
  const validatedValue = z.date().parse(value)
  const normalizedIsoDate = validatedValue.toISOString().replace(/\.\d{3}Z$/, 'Z')
  return make<CanvasDateType>()(normalizedIsoDate)
}
