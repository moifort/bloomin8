import { ImageQuery } from '~/domain/image/query'

export default defineEventHandler(async (event) => {
  const name = getRouterParam(event, 'name')
  if (!name) throw createError({ statusCode: 400, statusMessage: 'No id provided' })
  const file = await ImageQuery.findFileByName(name)
  if (!file) throw createError({ statusCode: 404, statusMessage: 'Not found' })
  setResponseHeader(event, 'content-type', 'image/jpeg')
  // An id always names the same bytes: cache the hit forever, never a 404 —
  // a miss can turn into a hit once the upload lands.
  setResponseHeader(event, 'cache-control', 'public, max-age=31536000, immutable')
  return file
})
