import { saveImage } from '~/images/index'

export default eventHandler(async (event) => {
  const orientation = (getQuery(event).orientation as 'P' | 'L' | undefined) ?? 'P'
  const image = await readRawBody(event, false)
  if (!image) throw createError({ statusCode: 400, statusMessage: 'No raw provided' })
  const { id, url } = await saveImage(image.toString('base64'), orientation)
  return { status: 200, data: { id, url } }
})
