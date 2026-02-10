import { config } from '~/config/index'

export default defineNitroPlugin(() => {
  console.log(`${JSON.stringify(config())}`)
})
