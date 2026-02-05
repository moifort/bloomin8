import type { IndexFile, PhotoEntry, Settings } from "./storage";

export type PickResult = {
  photo: PhotoEntry;
  settings: Settings;
};

export const pickPhoto = (index: IndexFile, settings: Settings): PickResult | null => {
  const total = index.photos.length;
  if (total === 0) return null;

  if (settings.shuffle) {
    const randomIndex = Math.floor(Math.random() * total);
    return { photo: index.photos[randomIndex], settings };
  }

  const safeCursor = Number.isFinite(settings.cursor) ? settings.cursor : 0;
  const nextIndex = safeCursor % total;
  const nextSettings: Settings = {
    ...settings,
    cursor: (nextIndex + 1) % total
  };

  return { photo: index.photos[nextIndex], settings: nextSettings };
};
