import { applySettingsUpdate, type Settings, type SettingsUpdate } from '../domain/model'
import { loadSettings, saveSettings } from '../infrastructure/storage'

export const getSettings = async (): Promise<Settings> => loadSettings()

export const updateSettings = async (update: SettingsUpdate): Promise<Settings> => {
  const current = await loadSettings()
  const next = applySettingsUpdate(current, update)
  await saveSettings(next)
  return next
}
