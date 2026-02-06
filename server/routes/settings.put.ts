import { updateSettings } from '../application/settings'
import type { SettingsUpdate } from '../domain/model'

export default eventHandler(async (event) => {
  const body = await readBody<unknown>(event)

  if (typeof body !== 'object' || body === null) {
    setResponseStatus(event, 400)
    return { status: 400, message: 'Invalid body' }
  }

  const update: SettingsUpdate = {}
  const input = body as Record<string, unknown>

  if (typeof input.intervalHours === 'number') {
    update.intervalHours = input.intervalHours
  }

  if (typeof input.shuffle === 'boolean') {
    update.shuffle = input.shuffle
  }

  const settings = await updateSettings(update)
  return { status: 200, data: settings }
})
