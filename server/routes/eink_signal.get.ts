import { Canvas } from '~/canvas/index'
import { config } from '~/config/index'

export default eventHandler(async () => {
  const { canvasUrl, serverUrl } = config()
  await Canvas.sleep(canvasUrl, serverUrl)
  return {
    status: 200,
    message: 'Feedback recorded',
  }
})
