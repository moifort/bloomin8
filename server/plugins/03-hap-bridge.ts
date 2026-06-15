import { Categories, HAPStorage } from 'hap-nodejs'
import { buildCanvasAccessory } from '~/domain/canvas/infrastructure/homekit/accessory'
import { createLogger } from '~/system/logger'
import { setHapBridge } from '~/utils/hap'

const log = createLogger('homekit')

export default defineNitroPlugin(async () => {
  const { homekit } = useRuntimeConfig()

  // hap-nodejs persists pairing state via node-persist (NOT Nitro storage),
  // so point it at ./data/hap alongside the other fs buckets. Deleting this
  // directory resets pairing — the accessory must then be re-added in Home.
  HAPStorage.setCustomStoragePath('./data/hap')

  const accessory = buildCanvasAccessory()
  await accessory.publish({
    username: homekit.username,
    pincode: homekit.pincode,
    port: Number(homekit.port),
    category: Categories.SWITCH,
  })
  setHapBridge(accessory)

  log.info(`HomeKit accessory published — add it in Apple Home with PIN ${homekit.pincode}`)
  log.info(`HomeKit setup URI: ${accessory.setupURI()}`)
})
