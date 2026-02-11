import { Canvas } from '~/canvas/index'
import { BatteryPercentage } from '~/canvas/primitives'

export default defineEventHandler(async (event) => {
  const { battery } = getQuery(event)
  if (!battery) return
  Canvas.saveBattery(BatteryPercentage(battery))
})
