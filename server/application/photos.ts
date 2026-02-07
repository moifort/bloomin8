import { createEmptyIndex } from '../domain/model'
import { clearImageFiles, saveIndex } from '../infrastructure/storage'

export type DeleteAllPhotosResult = {
  deletedFiles: number
}

export const deleteAllPhotos = async (): Promise<DeleteAllPhotosResult> => {
  const deletedFiles = await clearImageFiles()
  await saveIndex(createEmptyIndex())
  return { deletedFiles }
}
