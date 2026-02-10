/** biome-ignore-all lint/suspicious/noExplicitAny: only used for primitives */
import { make } from 'ts-brand'
import type {
  ImageId as ImageIdType,
  ImageOrientation as ImageOrientationType,
  ImageRaw as ImageRawType,
  ImageUrl as ImageUrlType,
} from '~/images/types'

export const randomImageId = () => ImageId(crypto.randomUUID())
export const ImageId = (value?: any) => {
  if (!value) throw new Error(`ImageId must be a uuid, received: ${value}`)
  if (typeof value !== 'string') throw new Error(`ImageId must be a string, received: ${value}`)
  if (value.length !== 36) throw new Error(`ImageId must be 36 characters long, received: ${value}`)
  return make<ImageIdType>()(value)
}

export const ImageUrl = (value?: any) => {
  if (!value) throw new Error(`ImageUrl must be a string, received: ${value}`)
  if (typeof value !== 'string') throw new Error(`ImageUrl must be a string, received: ${value}`)
  if (!value.startsWith('/')) throw new Error(`ImageUrl must start with /, received: ${value}`)
  return make<ImageUrlType>()(value)
}

export const ImageRaw = (value?: any) => {
  if (!value) throw new Error(`ImageRaw must be a string, received: ${value}`)
  if (typeof value !== 'string' && !Buffer.isBuffer(value))
    throw new Error(`ImageRaw must be a string, received: ${value}`)
  const raw = value instanceof Buffer ? value.toString('base64') : value
  if (!raw) throw new Error(`ImageRaw must be a string, received: ${raw}`)
  return make<ImageRawType>()(raw)
}

export const ImageOrientation = (value?: any) => {
  if (typeof value !== 'string')
    throw new Error(`ImageOrientation must be a 'P' or 'L', received: ${value}`)
  if (!value) throw new Error(`ImageOrientation must be 'P' or 'L', received: ${value}`)
  if (value !== 'P' && value !== 'L')
    throw new Error(`ImageOrientation must be 'P' or 'L', received: ${value}`)
  return make<ImageOrientationType>()(value)
}
