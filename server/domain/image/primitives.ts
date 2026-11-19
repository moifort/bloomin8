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

// The app sends 1200×1600 JPEGs of a few hundred KB: 10 MB leaves ample room.
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024

// Every JPEG starts with the SOI marker followed by another marker.
const JPEG_MAGIC = Buffer.from([0xff, 0xd8, 0xff])

// JPEG bytes. A string is the base64 form images were stored in before
// `image-files` existed (only read back by the startup migration).
export const ImageRaw = (value: unknown) => {
  const validatedValue = z.union([z.string(), z.instanceof(Buffer)]).parse(value)
  const bytes =
    typeof validatedValue === 'string' ? Buffer.from(validatedValue, 'base64') : validatedValue
  const jpegBytes = z
    .instanceof(Buffer)
    .refine((buffer) => buffer.length > 0, { message: 'Image must not be empty' })
    .refine((buffer) => buffer.length <= MAX_IMAGE_BYTES, {
      message: `Image must not exceed ${MAX_IMAGE_BYTES / 1024 / 1024} MB`,
    })
    .refine((buffer) => buffer.subarray(0, JPEG_MAGIC.length).equals(JPEG_MAGIC), {
      message: 'Image must be a JPEG',
    })
    .parse(bytes)
  return make<ImageRawType>()(jpegBytes)
}

export const ImageOrientation = (value: unknown) => {
  const validatedValue = z.enum(['P', 'L']).parse(value)
  return make<ImageOrientationType>()(validatedValue)
}
