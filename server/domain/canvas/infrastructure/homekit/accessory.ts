import { Accessory, Characteristic, Service, uuid } from 'hap-nodejs'
import { CanvasQuery } from '~/domain/canvas/query'
import { config } from '~/domain/config'
import { PlaylistCommand } from '~/domain/playlist/command'
import { PlaylistQuery } from '~/domain/playlist/query'
import { createLogger } from '~/system/logger'

const log = createLogger('homekit')

// Battery is reported as low at or below this percentage (matches the
// threshold the iOS app uses for its low-battery affordance).
const LOW_BATTERY_THRESHOLD = 20

/**
 * Builds the single HomeKit accessory exposing the Canvas device to Apple Home:
 * a Switch reflecting/driving the playlist running state, plus a Battery
 * service surfacing the last reported charge. All getters read live domain
 * state on demand via the public query/command namespaces — no duplicated state.
 */
export const buildCanvasAccessory = () => {
  const accessory = new Accessory('Canvas', uuid.generate('bloomin8:canvas'))

  accessory
    .getService(Service.AccessoryInformation)
    ?.setCharacteristic(Characteristic.Manufacturer, 'BLOOMIN8')
    .setCharacteristic(Characteristic.Model, 'Canvas')
    .setCharacteristic(Characteristic.SerialNumber, 'canvas-001')

  // Switch — on === playlist actively serving images.
  accessory
    .addService(Service.Switch, 'Canvas')
    .getCharacteristic(Characteristic.On)
    .onGet(async () => {
      const playlist = await PlaylistQuery.findById()
      return playlist?.status === 'in-progress'
    })
    .onSet(async (value) => {
      await setPlaying(Boolean(value))
    })

  // Battery — read-only mirror of the last device pull report.
  const battery = accessory.addService(Service.Battery, 'Battery')
  battery
    .getCharacteristic(Characteristic.BatteryLevel)
    .onGet(async () => (await CanvasQuery.getBattery())?.percentage ?? 0)
  battery.getCharacteristic(Characteristic.StatusLowBattery).onGet(async () => {
    const level = (await CanvasQuery.getBattery())?.percentage ?? 0
    return level <= LOW_BATTERY_THRESHOLD
      ? Characteristic.StatusLowBattery.BATTERY_LEVEL_LOW
      : Characteristic.StatusLowBattery.BATTERY_LEVEL_NORMAL
  })
  // The device never reports a charging state, so advertise a static value.
  battery.setCharacteristic(Characteristic.ChargingState, Characteristic.ChargingState.NOT_CHARGING)

  return accessory
}

/**
 * Maps the HomeKit On characteristic onto the playlist lifecycle. Tolerant by
 * design: command rejections (no playlist, wrong state, empty playlist) are
 * logged rather than surfaced as HomeKit errors — HomeKit re-reads the real
 * state via the On getter right after a set, so the switch self-corrects.
 */
const setPlaying = async (shouldPlay: boolean) => {
  const playlist = await PlaylistQuery.findById()
  if (!playlist) {
    log.warn('HomeKit switch toggled but no playlist exists yet — ignoring')
    return
  }
  const { serverUrl } = config()

  if (shouldPlay) {
    if (playlist.status === 'in-progress') return
    if (playlist.status === 'paused') {
      log.info('HomeKit → resume', await PlaylistCommand.resume(serverUrl))
      return
    }
    // status === 'stop' → restart from the last persisted configuration.
    log.info(
      'HomeKit → start',
      await PlaylistCommand.start(
        serverUrl,
        playlist.canvasUrl,
        playlist.cronIntervalInHours,
        playlist.quietHours,
      ),
    )
    return
  }

  if (playlist.status !== 'in-progress') return
  log.info('HomeKit → pause', await PlaylistCommand.pause())
}
