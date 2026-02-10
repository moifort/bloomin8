import { Images } from '~/images/index'

export default eventHandler(async (event) => {
  const name = getRouterParam(event, 'name')
  if (!name) throw createError({ statusCode: 400, statusMessage: 'No id provided' })
  const file = await Images.getByName(name)
  if (file === 'not-found') throw createError({ statusCode: 404, statusMessage: 'Not found' })
  setResponseHeader(event, 'content-type', 'image/jpeg')
  return Buffer.from(file.raw, 'base64')
})
