import { ImageId } from '~/domain/image/primitives'
import type { Image, ImageId as ImageIdType, ImageRaw } from '~/domain/image/types'

// Metadata lives in `images` as JSON; the JPEG bytes live in `image-files` as
// real files, served as-is. Images saved before this split kept the bytes
// inline as base64 (`raw`) — `ImageCommand.migrateInlineRaw` moves them out.
type StoredImage = Image & { raw?: string }

const metadataBucket = () => useStorage<StoredImage>('images')
const fileBucket = () => useStorage('image-files')
const fileKey = (id: ImageIdType) => `${id}.jpg`

export const findById = async (id: ImageIdType): Promise<Image | null> => {
  const stored = await metadataBucket().getItem(id)
  if (!stored) return null
  const { raw: _legacy, ...image } = stored
  return image
}

export const findFileById = async (id: ImageIdType) => {
  const file = await fileBucket().getItemRaw<Buffer>(fileKey(id))
  return file ?? null
}

export const findLegacyInlineRaw = async (id: ImageIdType) => {
  const stored = await metadataBucket().getItem(id)
  return stored?.raw ?? null
}

export const findAllIds = async () => {
  const keys = await metadataBucket().getKeys()
  return keys.map((key) => ImageId(key))
}

// File first: metadata only points at bytes that already exist.
export const save = async (image: Image, raw: ImageRaw) => {
  await fileBucket().setItemRaw(fileKey(image.id), raw)
  await metadataBucket().setItem(image.id, image)
}

export const remove = async (id: ImageIdType) => {
  await metadataBucket().removeItem(id)
  await fileBucket().removeItem(fileKey(id))
}
