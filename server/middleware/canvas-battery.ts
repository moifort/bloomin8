import { CanvasCommand } from '~/domain/canvas/command'
import { Percentage } from '~/domain/canvas/primitives'
import { createLogger } from '~/system/logger'

const log = createLogger('canvas')

export default defineEventHandler(async (event) => {
  if (!event.path.startsWith('/eink_pull')) return
  const { battery } = getQuery(event)
  if (!battery) return
  // A malformed battery report must never break the device pull response.
  try {
    await CanvasCommand.saveBattery(Percentage(battery))
  } catch (error) {
    log.warn('Ignoring invalid battery report', { battery, error })
  }
})
