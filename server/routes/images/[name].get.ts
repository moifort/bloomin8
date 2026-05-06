import { ImageQuery } from '~/domain/image/query'

export default defineEventHandler(async (event) => {
  const name = getRouterParam(event, 'name')
  if (!name) throw createError({ statusCode: 400, statusMessage: 'No id provided' })
  const file = await ImageQuery.findByName(name)
  if (!file) throw createError({ statusCode: 404, statusMessage: 'Not found' })
  setResponseHeader(event, 'content-type', 'image/jpeg')
  return Buffer.from(file.raw, 'base64')
})
