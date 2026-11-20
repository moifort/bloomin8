import type { Battery } from '~/domain/canvas/types'

const bucket = () => useStorage('canvas')

export const findBattery = async () => {
  const battery = await bucket().getItem<Battery>('battery')
  return battery ?? null
}

export const saveBattery = async (battery: Battery) => {
  await bucket().setItem('battery', battery)
}

// Host (with port) the device used for its last pull, e.g. `192.168.1.199:3000`.
export const findPulledVia = async () => {
  const host = await bucket().getItem<string>('pulledVia')
  return host ?? null
}

export const savePulledVia = async (host: string) => {
  await bucket().setItem('pulledVia', host)
}
