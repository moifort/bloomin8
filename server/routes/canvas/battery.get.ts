import { Canvas } from '~/canvas/index'

export default defineEventHandler(async () => {
  const level = await Canvas.getBattery()
  if (level === 'battery-unavailable') return { status: 200, data: 'battery-unavailable' }
  return { status: 200, data: level }
})
