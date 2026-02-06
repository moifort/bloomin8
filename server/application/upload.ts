import type { PhotoEntry } from '../domain/model'
import { err, ok, type Result } from '../domain/result'
import { parseUploadFilename, type UploadFilenameError } from '../domain/upload'
import { loadIndex, saveIndex, writeImageFile } from '../infrastructure/storage'

export type UploadPhotoError = UploadFilenameError | { type: 'empty_body'; message: string }

export type UploadPhotoResult = {
  file: string
  entry: PhotoEntry
}

export const uploadPhoto = async (input: {
  filename: string
  body: Uint8Array | null
  now?: Date
}): Promise<Result<UploadPhotoResult, UploadPhotoError>> => {
  const parsed = parseUploadFilename(input.filename)
  if (!parsed.ok) {
    return err(parsed.error)
  }

  if (!input.body || input.body.length === 0) {
    return err({ type: 'empty_body', message: 'Empty body' })
  }

  await writeImageFile(parsed.value.fileName, input.body)

  const index = await loadIndex()
  const entry: PhotoEntry = {
    file: parsed.value.fileName,
    orientation: parsed.value.orientation,
    addedAt: (input.now ?? new Date()).toISOString(),
  }

  const nextIndex = {
    photos: [...index.photos, entry],
  }

  await saveIndex(nextIndex)

  return ok({ file: parsed.value.fileName, entry })
}
