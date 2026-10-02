import { make } from 'ts-brand'
import { z } from 'zod'
import type {
  ImageId as ImageIdType,
  ImageOrientation as ImageOrientationType,
  ImageRaw as ImageRawType,
  ImageUrl as ImageUrlType,
} from '~/domain/image/types'

export const randomImageId = () => ImageId(crypto.randomUUID())

export const ImageId = (value: unknown) => {
  const validatedValue = z.uuid().parse(value)
  return make<ImageIdType>()(validatedValue)
}

export const ImageUrl = (value: unknown) => {
  const validatedValue = z.string().startsWith('/').parse(value)
  return make<ImageUrlType>()(validatedValue)
}

// JPEG bytes. A string is the base64 form images were stored in before
// `image-files` existed (only read back by the startup migration).
export const ImageRaw = (value: unknown) => {
  const validatedValue = z.union([z.string(), z.instanceof(Buffer)]).parse(value)
  const bytes =
    typeof validatedValue === 'string' ? Buffer.from(validatedValue, 'base64') : validatedValue
  const nonEmptyBytes = z
    .instanceof(Buffer)
    .refine((buffer) => buffer.length > 0, { message: 'Image must not be empty' })
    .parse(bytes)
  return make<ImageRawType>()(nonEmptyBytes)
}

export const ImageOrientation = (value: unknown) => {
  const validatedValue = z.enum(['P', 'L']).parse(value)
  return make<ImageOrientationType>()(validatedValue)
}
