import type { Orientation } from './model'
import { err, ok, type Result } from './result'

export type UploadFilenameError =
  | { type: 'invalid_filename'; message: string }
  | { type: 'invalid_extension'; message: string }
  | { type: 'invalid_orientation'; message: string }

export type ParsedUploadFilename = {
  fileName: string
  orientation: Orientation
}

const hasUnsafePath = (value: string): boolean =>
  value.includes('/') || value.includes('\\') || value.includes('\0')

export const parseUploadFilename = (
  raw: string,
): Result<ParsedUploadFilename, UploadFilenameError> => {
  if (!raw || hasUnsafePath(raw)) {
    return err({ type: 'invalid_filename', message: 'Invalid filename' })
  }

  const hasJpegExtension = raw.endsWith('.jpg') || raw.endsWith('.jpeg')
  if (!hasJpegExtension) {
    return err({
      type: 'invalid_extension',
      message: 'Only .jpg/.jpeg allowed',
    })
  }

  const orientation =
    raw.endsWith('_P.jpg') || raw.endsWith('_P.jpeg')
      ? 'P'
      : raw.endsWith('_L.jpg') || raw.endsWith('_L.jpeg')
        ? 'L'
        : null

  if (!orientation) {
    return err({
      type: 'invalid_orientation',
      message: 'Filename must end with _P.jpg or _L.jpg',
    })
  }

  return ok({ fileName: raw, orientation })
}
