import type { Battery } from '~/domain/canvas/types'

const bucket = () => useStorage<Battery>('canvas')

export const findBattery = async () => {
  const battery = await bucket().getItem('battery')
  return battery ?? null
}

export const saveBattery = async (battery: Battery) => {
  await bucket().setItem('battery', battery)
}
