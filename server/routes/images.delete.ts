import { ImageCommand } from '~/domain/image/command'

export default defineEventHandler(async () => {
  await ImageCommand.deleteAll()
  return { status: 200, message: 'All images deleted' }
})
