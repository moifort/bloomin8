import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export type Orientation = "P" | "L";

export type PhotoEntry = {
  file: string;
  orientation: Orientation;
  addedAt: string;
};

export type IndexFile = {
  photos: PhotoEntry[];
};

export type Settings = {
  intervalHours: number;
  shuffle: boolean;
  cursor: number;
};

const dataDir = process.env.DATA_DIR ?? "data";
const imagesDir = join(dataDir, "images");
const indexPath = join(dataDir, "index.json");
const settingsPath = join(dataDir, "settings.json");

const defaultIndex: IndexFile = { photos: [] };
const defaultSettings: Settings = { intervalHours: 2, shuffle: true, cursor: 0 };

export const paths = {
  dataDir,
  imagesDir,
  indexPath,
  settingsPath
};

const readJson = async <T>(path: string, fallback: T): Promise<T> => {
  try {
    const raw = await readFile(path, "utf8");
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
};

const writeJsonAtomic = async <T>(path: string, value: T): Promise<void> => {
  const dir = dirname(path);
  const tmpPath = join(dir, `.${Date.now()}-${Math.random().toString(16).slice(2)}.tmp`);
  const payload = JSON.stringify(value, null, 2);
  await writeFile(tmpPath, payload, "utf8");
  await rename(tmpPath, path);
};

export const ensureDataDirs = async (): Promise<void> => {
  await mkdir(imagesDir, { recursive: true });
  const currentIndex = await readJson(indexPath, defaultIndex);
  const currentSettings = await readJson(settingsPath, defaultSettings);
  await writeJsonAtomic(indexPath, currentIndex);
  await writeJsonAtomic(settingsPath, currentSettings);
};

export const loadIndex = async (): Promise<IndexFile> => {
  await ensureDataDirs();
  return readJson(indexPath, defaultIndex);
};

export const saveIndex = async (index: IndexFile): Promise<void> => {
  await ensureDataDirs();
  await writeJsonAtomic(indexPath, index);
};

export const loadSettings = async (): Promise<Settings> => {
  await ensureDataDirs();
  return readJson(settingsPath, defaultSettings);
};

export const saveSettings = async (settings: Settings): Promise<void> => {
  await ensureDataDirs();
  await writeJsonAtomic(settingsPath, settings);
};
