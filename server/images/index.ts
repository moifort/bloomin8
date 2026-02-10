import { ImageId, ImageUrl, randomImageId } from '~/images/primitives'
import type { Image, ImageId as ImageIdType, ImageOrientation, ImageRaw } from '~/images/types'

export namespace Images {
  export const save = async (raw: ImageRaw, orientation: ImageOrientation) => {
    const storage = useStorage('images')
    const id = randomImageId()
    const image: Image = {
      id,
      raw,
      orientation,
      createdAt: new Date(),
      url: ImageUrl(`/images/${id}_${orientation}.jpg`),
    }
    await storage.setItem<Image>(id, image)
    return image
  }

  export const getByName = async (name: string) => {
    const [extractId] = name.split('_')
    if (!extractId) return 'not-found' as const
    const id = ImageId(extractId)
    return getById(id)
  }

  export const getById = async (id: ImageIdType) => {
    const storage = useStorage('images')
    const image = await storage.getItem<Image>(id)
    if (!image) return 'not-found' as const
    return image
  }

  export const getAllImagesId = async () => {
    const storage = useStorage('images')
    return await storage.getKeys().then((keys) => keys.map((key) => ImageId(key)))
  }
}
