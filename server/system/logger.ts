import { consola } from 'consola'

export const createLogger = (tag: string) => consola.withTag(tag)
