import { readImageFile } from '../../infrastructure/storage'

export default eventHandler(async (event) => {
  const param = getRouterParam(event, 'path')
  if (!param || param.includes('/') || param.includes('\\')) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid path' })
  }

  try {
    const file = await readImageFile(param)
    setResponseHeader(event, 'content-type', 'image/jpeg')
    return file
  } catch {
    throw createError({ statusCode: 404, statusMessage: 'Not found' })
  }
})
