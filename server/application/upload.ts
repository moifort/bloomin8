import type { PhotoEntry } from '../domain/model'
import { err, ok, type Result } from '../domain/result'
import {
  buildUploadFileName,
  parseUploadOrientation,
  type UploadOrientationError,
} from '../domain/upload'
import { loadIndex, saveIndex, writeImageFile } from '../infrastructure/storage'

export type UploadPhotoError = UploadOrientationError | { type: 'empty_body'; message: string }

export type UploadPhotoResult = {
  file: string
  entry: PhotoEntry
}

export const uploadPhoto = async (input: {
  orientation: string
  body: Uint8Array | null
  now?: Date
}): Promise<Result<UploadPhotoResult, UploadPhotoError>> => {
  const parsedOrientation = parseUploadOrientation(input.orientation)
  if (!parsedOrientation.ok) {
    return err(parsedOrientation.error)
  }

  if (!input.body || input.body.length === 0) {
    return err({ type: 'empty_body', message: 'Empty body' })
  }

  const generated = buildUploadFileName(parsedOrientation.value)

  await writeImageFile(generated.fileName, input.body)

  const index = await loadIndex()
  const entry: PhotoEntry = {
    file: generated.fileName,
    orientation: generated.orientation,
    addedAt: (input.now ?? new Date()).toISOString(),
  }

  const nextIndex = {
    photos: [...index.photos, entry],
  }

  await saveIndex(nextIndex)

  return ok({ file: generated.fileName, entry })
}
