import { imagesToDeleteForKeeping } from '~/domain/image/business-rules'
import * as imageRepository from '~/domain/image/infrastructure/repository'
import { ImageRaw, ImageUrl, randomImageId } from '~/domain/image/primitives'
import type {
  Image,
  ImageId,
  ImageOrientation,
  ImageRaw as ImageRawType,
} from '~/domain/image/types'

export namespace ImageCommand {
  export const save = async (raw: ImageRawType, orientation: ImageOrientation) => {
    const id = randomImageId()
    const image: Image = {
      id,
      orientation,
      createdAt: new Date(),
      url: ImageUrl(`/images/${id}_${orientation}.jpg`),
    }
    await imageRepository.save(image, raw)
    return image
  }

  export const deleteAll = async () => {
    const ids = await imageRepository.findAllIds()
    await Promise.all(ids.map((id) => imageRepository.remove(id)))
    return ids.length
  }

  // Album replacement, step 2: the app uploads the new album first (the device
  // keeps showing the old one meanwhile), then drops everything else.
  export const keepOnly = async (keepImagesId: ImageId[]) => {
    const toDelete = imagesToDeleteForKeeping(await imageRepository.findAllIds(), keepImagesId)
    if (!toDelete) return 'no-kept-image' as const
    await Promise.all(toDelete.map((id) => imageRepository.remove(id)))
    return toDelete.length
  }

  // Rollback of a cancelled upload. Unknown ids are ignored.
  export const deleteMany = async (imagesId: ImageId[]) => {
    const existing = new Set(await imageRepository.findAllIds())
    const toDelete = imagesId.filter((id) => existing.has(id))
    await Promise.all(toDelete.map((id) => imageRepository.remove(id)))
    return toDelete.length
  }

  // One-shot move of base64-inline images to real JPEG files. Idempotent:
  // an interrupted run is simply resumed at the next startup.
  export const migrateInlineRaw = async () => {
    let migrated = 0
    for (const id of await imageRepository.findAllIds()) {
      const inlineRaw = await imageRepository.findLegacyInlineRaw(id)
      const image = inlineRaw && (await imageRepository.findById(id))
      if (!inlineRaw || !image) continue
      await imageRepository.save(image, ImageRaw(inlineRaw))
      migrated++
    }
    return migrated
  }
}
