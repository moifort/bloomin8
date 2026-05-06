import { ImageId } from '~/domain/image/primitives'
import type { Image, ImageId as ImageIdType } from '~/domain/image/types'

const bucket = () => useStorage<Image>('images')

export const findById = async (id: ImageIdType) => {
  const image = await bucket().getItem(id)
  return image ?? null
}

export const findAllIds = async () => {
  const keys = await bucket().getKeys()
  return keys.map((key) => ImageId(key))
}

export const save = async (image: Image) => {
  await bucket().setItem(image.id, image)
}

export const remove = async (id: ImageIdType) => {
  await bucket().removeItem(id)
}
