import { Images } from '~/images/index'

export default eventHandler(async () => {
  await Images.deleteAll()
  return {
    status: 200,
    message: `All images deleted`,
  }
})
