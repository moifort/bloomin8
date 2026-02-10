import { Images } from '~/images/index'
import { ImageOrientation, ImageRaw } from '~/images/primitives'

export default eventHandler(async (event) => {
  const orientation = ImageOrientation(getQuery(event).orientation)
  const image = await readRawBody(event, false)
  if (!image) throw createError({ statusCode: 400, statusMessage: 'No raw provided' })
  const { id, url } = await Images.save(ImageRaw(image), orientation)
  return { status: 200, data: { id, url } }
})
