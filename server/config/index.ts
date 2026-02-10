import { CanvasUrl, Hour, ServerUrl } from '~/config/primitives'

export const config = () => {
  const config = useRuntimeConfig()
  console.log(`${JSON.stringify(config)}`)
  return {
    canvasUrl: CanvasUrl(config.canvasUrl),
    serverUrl: ServerUrl(config.serverUrl),
    cronIntervalInHours: Hour(config.cronIntervalInHours),
  }
}
