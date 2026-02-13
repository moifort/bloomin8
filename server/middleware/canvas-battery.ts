import { Canvas } from '~/canvas/index'
import { Percentage } from '~/canvas/primitives'

export default defineEventHandler(async (event) => {
  const { battery } = getQuery(event)
  if (!battery) return
  Canvas.saveBattery(Percentage(battery))
})
