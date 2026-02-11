import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  ImageId as ImageIdType,
  ImageOrientation as ImageOrientationType,
  ImageRaw as ImageRawType,
  ImageUrl as ImageUrlType,
} from '~/images/types'

export const randomImageId = () => ImageId(crypto.randomUUID())
export const ImageId = (value: unknown) => {
  const validatedValue = z.uuid().parse(value)
  return make<ImageIdType>()(validatedValue)
}

export const ImageUrl = (value: unknown) => {
  const validatedValue = z.string().startsWith('/').parse(value)
  return make<ImageUrlType>()(validatedValue)
}

export const ImageRaw = (value: unknown) => {
  const validatedValue = z.union([z.string(), z.instanceof(Buffer)]).parse(value)
  const normalizedRaw = validatedValue instanceof Buffer ? validatedValue.toString('base64') : validatedValue
  const nonEmptyRaw = z.string().min(1).parse(normalizedRaw)
  return make<ImageRawType>()(nonEmptyRaw)
}

export const ImageOrientation = (value: unknown) => {
  const validatedValue = z.enum(['P', 'L']).parse(value)
  return make<ImageOrientationType>()(validatedValue)
}
