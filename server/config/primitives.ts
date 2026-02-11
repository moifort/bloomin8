import { make } from 'ts-brand'
import { z } from 'zod'
import type { ServerUrl as ServerUrlType } from '~/config/types'

export const ServerUrl = (value: unknown) => {
  const validatedValue = z.url().parse(value)
  return make<ServerUrlType>()(validatedValue)
}
