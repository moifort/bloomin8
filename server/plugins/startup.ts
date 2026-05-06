import { config } from '~/domain/config'

export default defineNitroPlugin(() => {
  console.log(`${JSON.stringify(config())}`)
})
