import * as imageRepository from '~/domain/image/infrastructure/repository'
import { ImageUrl, randomImageId } from '~/domain/image/primitives'
import type { Image, ImageOrientation, ImageRaw } from '~/domain/image/types'

export namespace ImageCommand {
  export const save = async (raw: ImageRaw, orientation: ImageOrientation) => {
    const id = randomImageId()
    const image: Image = {
      id,
      raw,
      orientation,
      createdAt: new Date(),
      url: ImageUrl(`/images/${id}_${orientation}.jpg`),
    }
    await imageRepository.save(image)
    return image
  }

  export const deleteAll = async () => {
    const ids = await imageRepository.findAllIds()
    await Promise.all(ids.map((id) => imageRepository.remove(id)))
    return ids.length
  }
}
