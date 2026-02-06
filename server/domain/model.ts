export type Orientation = 'P' | 'L'

export type PhotoEntry = {
  file: string
  orientation: Orientation
  addedAt: string
}

export type IndexFile = {
  photos: PhotoEntry[]
}

export type Settings = {
  intervalHours: number
  shuffle: boolean
  cursor: number
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null

const isOrientation = (value: unknown): value is Orientation => value === 'P' || value === 'L'

const isPhotoEntry = (value: unknown): value is PhotoEntry => {
  if (!isRecord(value)) return false
  return (
    typeof value.file === 'string' &&
    typeof value.addedAt === 'string' &&
    isOrientation(value.orientation)
  )
}

export const isIndexFile = (value: unknown): value is IndexFile => {
  if (!isRecord(value)) return false
  if (!Array.isArray(value.photos)) return false
  return value.photos.every(isPhotoEntry)
}

export const isSettings = (value: unknown): value is Settings => {
  if (!isRecord(value)) return false
  return (
    typeof value.intervalHours === 'number' &&
    Number.isFinite(value.intervalHours) &&
    value.intervalHours >= 1 &&
    typeof value.shuffle === 'boolean' &&
    typeof value.cursor === 'number' &&
    Number.isFinite(value.cursor) &&
    value.cursor >= 0
  )
}

export const createDefaultSettings = (): Settings => ({
  intervalHours: 2,
  shuffle: true,
  cursor: 0,
})

export const createEmptyIndex = (): IndexFile => ({ photos: [] })

export const normalizeSettings = (
  value: unknown,
  fallback: Settings = createDefaultSettings(),
): Settings => (isSettings(value) ? value : fallback)

export const normalizeIndex = (
  value: unknown,
  fallback: IndexFile = createEmptyIndex(),
): IndexFile => (isIndexFile(value) ? value : fallback)

export type SettingsUpdate = Partial<Pick<Settings, 'intervalHours' | 'shuffle'>>

export const applySettingsUpdate = (current: Settings, update: SettingsUpdate): Settings => {
  const intervalHours =
    typeof update.intervalHours === 'number' &&
    Number.isFinite(update.intervalHours) &&
    update.intervalHours >= 1
      ? update.intervalHours
      : current.intervalHours

  const shuffle = typeof update.shuffle === 'boolean' ? update.shuffle : current.shuffle

  return {
    ...current,
    intervalHours,
    shuffle,
  }
}
