import * as imageRepository from '~/domain/image/infrastructure/repository'
import { ImageId } from '~/domain/image/primitives'
import type { ImageId as ImageIdType } from '~/domain/image/types'

export namespace ImageQuery {
  export const findById = (id: ImageIdType) => imageRepository.findById(id)

  // `<id>_P.jpg` → JPEG bytes. A malformed id is a not-found, not a server error.
  export const findFileByName = async (name: string) => {
    const [extractedId] = name.split('_')
    try {
      return await imageRepository.findFileById(ImageId(extractedId))
    } catch {
      return null
    }
  }

  export const findAllIds = () => imageRepository.findAllIds()
}
