import { uploadPhoto } from '../application/upload'

export default eventHandler(async (event) => {
  const query = getQuery(event)
  const rawOrientation = typeof query.orientation === 'string' ? query.orientation : 'P'
  const body = await readRawBody(event, false)
  const bytes = body instanceof Uint8Array ? body : null
  const result = await uploadPhoto({
    orientation: rawOrientation,
    body: bytes,
  })

  if (!result.ok) {
    setResponseStatus(event, 400)
    return { status: 400, message: result.error.message }
  }

  return {
    status: 200,
    message: 'Uploaded',
    data: { file: result.value.file },
  }
})
