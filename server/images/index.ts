import { ImageUrl, randomImageId } from '~/images/primitives'
import type { Image, ImageId, ImageOrientation, ImageRaw } from '~/images/types'

export const saveImage = async (raw: ImageRaw, orientation: ImageOrientation) => {
  const storage = useStorage('images')
  const id = randomImageId()
  const image: Image = {
    id,
    raw,
    orientation,
    createdAt: new Date(),
    url: ImageUrl(`/images/${id}.jpeg`),
  }
  await storage.setItem<Image>(id, image)
  return image
}

export const getImage = async (id: ImageId) => {
  const storage = useStorage('images')
  const image = await storage.getItem<Image>(id)
  if (!image) return 'not-found' as const
  return image
}
