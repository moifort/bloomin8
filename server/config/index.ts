import { ServerUrl } from '~/config/primitives'

export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    serverUrl: ServerUrl(runtimeConfig.serverUrl),
  }
}
