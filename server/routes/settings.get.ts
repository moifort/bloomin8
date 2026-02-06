import { getSettings } from '../application/settings'

export default eventHandler(async () => {
  const settings = await getSettings()
  return { status: 200, data: settings }
})
