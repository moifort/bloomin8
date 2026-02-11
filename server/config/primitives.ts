/** biome-ignore-all lint/suspicious/noExplicitAny: only used for primitives */
import { make } from 'ts-brand'
import type { ServerUrl as ServerUrlType } from '~/config/types'

export const ServerUrl = make<ServerUrlType>()
