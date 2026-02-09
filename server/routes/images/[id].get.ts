import { getImage } from '~/images/index'
import { ImageId } from '~/images/primitives'

export default eventHandler(async (event) => {
  const id = ImageId(getRouterParam(event, 'id'))
  const file = await getImage(id)
  if (file === 'not-found') throw createError({ statusCode: 404, statusMessage: 'Not found' })
  setResponseHeader(event, 'content-type', 'image/jpeg')
  return Buffer.from(file.raw, 'base64')
})
