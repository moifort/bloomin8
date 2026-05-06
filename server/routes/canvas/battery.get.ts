import { CanvasQuery } from '~/domain/canvas/query'

export default defineEventHandler(async () => {
  const battery = await CanvasQuery.getBattery()
  if (!battery) return { status: 200, data: 'battery-unavailable' }
  return {
    status: 200,
    data: {
      percentage: battery.percentage,
      lastFullChargeDate: battery.lastFullChargeDate,
      lastPullDate: battery.lastPullDate,
    },
  }
})
