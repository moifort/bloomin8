import { CanvasUrl, Hour, ServerUrl } from '~/config/primitives'

export const config = () => {
  const config = useRuntimeConfig()
  return {
    canvasUrl: CanvasUrl(config.canvasUrl),
    serverUrl: ServerUrl(config.serverUrl),
    cronIntervalInHours: Hour(config.cronIntervalInHours),
  }
}
