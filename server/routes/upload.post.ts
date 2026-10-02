import { ImageCommand } from '~/domain/image/command'
import { ImageOrientation, ImageRaw } from '~/domain/image/primitives'

export default defineEventHandler(async (event) => {
  const orientation = parseOrientation(getQuery(event).orientation)
  const image = await readRawBody(event, false)
  if (!image) throw createError({ statusCode: 400, statusMessage: 'No raw provided' })
  const { id, url } = await ImageCommand.save(ImageRaw(image), orientation)
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
