import { defineEventHandler, readBody } from "h3";
import { loadSettings, saveSettings, type Settings } from "../lib/storage";

type SettingsUpdate = Partial<Pick<Settings, "intervalHours" | "shuffle">>;

export default defineEventHandler(async (event) => {
  const body = (await readBody<unknown>(event)) ?? {};
  const current = await loadSettings();

  if (typeof body !== "object" || body === null) {
    return { status: 400, message: "Invalid body" };
  }

  const update = body as SettingsUpdate;
  const intervalHours =
    typeof update.intervalHours === "number" && Number.isFinite(update.intervalHours) && update.intervalHours >= 1
      ? update.intervalHours
      : current.intervalHours;

  const shuffle = typeof update.shuffle === "boolean" ? update.shuffle : current.shuffle;

  const next: Settings = {
    ...current,
    intervalHours,
    shuffle
  };

  await saveSettings(next);
  return { status: 200, data: next };
});
