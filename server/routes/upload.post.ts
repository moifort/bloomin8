import { ImageCommand } from '~/domain/image/command'
import { ImageOrientation, ImageRaw } from '~/domain/image/primitives'

export default defineEventHandler(async (event) => {
  const orientation = ImageOrientation(getQuery(event).orientation)
  const image = await readRawBody(event, false)
  if (!image) throw createError({ statusCode: 400, statusMessage: 'No raw provided' })
  const { id, url } = await ImageCommand.save(ImageRaw(image), orientation)
  return { status: 200, data: { id, url } }
})
