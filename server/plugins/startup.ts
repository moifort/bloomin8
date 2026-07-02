import { config } from '~/domain/config'
import { createLogger } from '~/system/logger'

export default defineNitroPlugin(() => {
  createLogger('startup').info('Runtime config', config())
})
