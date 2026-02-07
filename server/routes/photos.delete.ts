import { deleteAllPhotos } from '../application/photos'

export default eventHandler(async () => {
  const result = await deleteAllPhotos()

  return {
    status: 200,
    message: 'All photos deleted',
    data: result,
  }
})
