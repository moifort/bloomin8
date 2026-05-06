import * as imageRepository from '~/domain/image/infrastructure/repository'
import { ImageId } from '~/domain/image/primitives'
import type { ImageId as ImageIdType } from '~/domain/image/types'

export namespace ImageQuery {
  export const findById = (id: ImageIdType) => imageRepository.findById(id)

  export const findByName = async (name: string) => {
    const [extractedId] = name.split('_')
    if (!extractedId) return null
    return imageRepository.findById(ImageId(extractedId))
  }

  export const findAllIds = () => imageRepository.findAllIds()
}
