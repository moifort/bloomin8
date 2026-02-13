import { Canvas } from '~/canvas/index'

export default defineEventHandler(async () => {
  const battery = await Canvas.getBattery()
  if (battery === 'battery-unavailable') return { status: 200, data: 'battery-unavailable' }
  return {
    status: 200,
    data: {
      percentage: battery.percentage,
      lastFullChargeDate: battery.lastFullChargeDate,
    },
  }
})
