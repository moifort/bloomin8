import { CanvasCommand } from '~/domain/canvas/command'
import { Percentage } from '~/domain/canvas/primitives'

export default defineEventHandler(async (event) => {
  const { battery } = getQuery(event)
  if (!battery) return
  CanvasCommand.saveBattery(Percentage(battery))
})
