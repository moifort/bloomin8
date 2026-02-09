import { getImage } from '~/images/index'

export default eventHandler(async (event) => {
  const id = getRouterParam(event, 'id') as string
  const file = await getImage(id)
  if (file === 'not-found') throw createError({ statusCode: 404, statusMessage: 'Not found' })
  setResponseHeader(event, 'content-type', 'image/jpeg')
  return Buffer.from(file.raw, 'base64')
})
