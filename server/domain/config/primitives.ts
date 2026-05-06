import { make } from 'ts-brand'
import { z } from 'zod'
import type { CanvasUrl as CanvasUrlType, ServerUrl as ServerUrlType } from '~/domain/config/types'

export const CanvasUrl = (value: unknown) => {
  const validatedValue = z.url().parse(value)
  return make<CanvasUrlType>()(validatedValue)
}

export const ServerUrl = (value: unknown) => {
  const validatedValue = z.url().parse(value)
  return make<ServerUrlType>()(validatedValue)
}
