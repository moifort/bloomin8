import { mkdir, readFile, readdir, rename, unlink, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import {
  createDefaultSettings,
  createEmptyIndex,
  type IndexFile,
  normalizeIndex,
  normalizeSettings,
  type Settings,
} from '../domain/model'

const dataDir = process.env.DATA_DIR ?? 'data'
const imagesDir = join(dataDir, 'images')
const indexPath = join(dataDir, 'index.json')
const settingsPath = join(dataDir, 'settings.json')

export const paths = {
  dataDir,
  imagesDir,
  indexPath,
  settingsPath,
}

const readJson = async (path: string): Promise<unknown> => {
  try {
    const raw = await readFile(path, 'utf8')
    return JSON.parse(raw) as unknown
  } catch {
    return null
  }
}

const writeJsonAtomic = async (path: string, value: unknown): Promise<void> => {
  const dir = dirname(path)
  const tmpPath = join(dir, `.${Date.now()}-${Math.random().toString(16).slice(2)}.tmp`)
  const payload = JSON.stringify(value, null, 2)
  await writeFile(tmpPath, payload, 'utf8')
  await rename(tmpPath, path)
}

export const ensureDataDirs = async (): Promise<void> => {
  await mkdir(imagesDir, { recursive: true })
  const [rawIndex, rawSettings] = await Promise.all([readJson(indexPath), readJson(settingsPath)])
  const currentIndex = normalizeIndex(rawIndex, createEmptyIndex())
  const currentSettings = normalizeSettings(rawSettings, createDefaultSettings())
  await Promise.all([
    writeJsonAtomic(indexPath, currentIndex),
    writeJsonAtomic(settingsPath, currentSettings),
  ])
}

export const loadIndex = async (): Promise<IndexFile> => {
  await ensureDataDirs()
  const raw = await readJson(indexPath)
  return normalizeIndex(raw, createEmptyIndex())
}

export const saveIndex = async (index: IndexFile): Promise<void> => {
  await ensureDataDirs()
  await writeJsonAtomic(indexPath, index)
}

export const loadSettings = async (): Promise<Settings> => {
  await ensureDataDirs()
  const raw = await readJson(settingsPath)
  return normalizeSettings(raw, createDefaultSettings())
}

export const saveSettings = async (settings: Settings): Promise<void> => {
  await ensureDataDirs()
  await writeJsonAtomic(settingsPath, settings)
}

export const writeImageFile = async (fileName: string, contents: Uint8Array): Promise<void> => {
  await ensureDataDirs()
  const targetPath = join(imagesDir, fileName)
  await writeFile(targetPath, contents)
}

export const readImageFile = async (fileName: string): Promise<Buffer> => {
  const targetPath = join(imagesDir, fileName)
  return readFile(targetPath)
}

export const clearImageFiles = async (): Promise<number> => {
  await ensureDataDirs()
  const entries = await readdir(imagesDir, { withFileTypes: true })
  const files = entries.filter((entry) => entry.isFile()).map((entry) => entry.name)

  await Promise.all(files.map((file) => unlink(join(imagesDir, file))))

  return files.length
}
