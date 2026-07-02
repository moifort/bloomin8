import * as imageRepository from '~/domain/image/infrastructure/repository'
import { ImageId } from '~/domain/image/primitives'
import type { ImageId as ImageIdType } from '~/domain/image/types'

export namespace ImageQuery {
  export const findById = (id: ImageIdType) => imageRepository.findById(id)

  export const findByName = async (name: string) => {
    const [extractedId] = name.split('_')
    if (!extractedId) return null
    // A malformed id is a not-found, not a server error.
    try {
      return await imageRepository.findById(ImageId(extractedId))
    } catch {
      return null
    }
  }

  export const findAllIds = () => imageRepository.findAllIds()
}
