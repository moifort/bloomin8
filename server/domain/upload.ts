import { randomBytes } from 'node:crypto'
import type { Orientation } from './model'
import { err, ok, type Result } from './result'

export type UploadOrientationError = { type: 'invalid_orientation'; message: string }

export type GeneratedUploadName = {
  fileName: string
  orientation: Orientation
}

export const parseUploadOrientation = (
  raw: string,
): Result<Orientation, UploadOrientationError> => {
  const normalized = raw.trim().toUpperCase()
  if (normalized === 'P' || normalized === 'L') {
    return ok(normalized)
  }

  return err({
    type: 'invalid_orientation',
    message: 'Orientation must be P or L',
  })
}

export const buildUploadFileName = (orientation: Orientation): GeneratedUploadName => {
  const randomName = randomBytes(12).toString('hex')
  return {
    fileName: `${randomName}_${orientation}.jpg`,
    orientation,
  }
}
