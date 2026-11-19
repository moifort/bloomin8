import { z } from 'zod'
import { ImageCommand } from '~/domain/image/command'
import { ImageOrientation, ImageRaw, MAX_IMAGE_BYTES } from '~/domain/image/primitives'

export default defineEventHandler(async (event) => {
  const orientation = parseOrientation(getQuery(event).orientation)
  // Refuse an oversized upload before buffering it.
  const contentLength = Number(getRequestHeader(event, 'content-length'))
  if (contentLength > MAX_IMAGE_BYTES) {
    throw createError({
      statusCode: 400,
      statusMessage: `Image must not exceed ${MAX_IMAGE_BYTES / 1024 / 1024} MB`,
    })
  }
  const image = await readRawBody(event, false)
  if (!image) throw createError({ statusCode: 400, statusMessage: 'No raw provided' })
  const { id, url } = await ImageCommand.save(parseImage(image), orientation)
  return { status: 200, data: { id, url } }
})

// A bad query param is a client error, not a 500.
const parseOrientation = (value: unknown) => {
  try {
    return ImageOrientation(value)
  } catch {
    throw createError({ statusCode: 400, statusMessage: 'orientation must be P or L' })
  }
}

// Not a JPEG, or too large: a 400 carrying the validation message.
const parseImage = (bytes: Buffer) => {
  try {
    return ImageRaw(bytes)
  } catch (error) {
    const message =
      error instanceof z.ZodError ? (error.issues[0]?.message ?? 'Invalid image') : 'Invalid image'
    throw createError({ statusCode: 400, statusMessage: message })
  }
}
