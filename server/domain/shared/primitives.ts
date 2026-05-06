import { make } from 'ts-brand'
import { z } from 'zod'
import type { Hour as HourType } from '~/domain/shared/types'

export const Hour = (value: unknown) => {
  const validatedValue = z
    .preprocess(
      (currentValue) => (typeof currentValue === 'string' ? Number(currentValue) : currentValue),
      z.number().int().min(1).max(168),
    )
    .parse(value)
  return make<HourType>()(validatedValue)
}
