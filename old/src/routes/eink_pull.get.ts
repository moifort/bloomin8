import { defineEventHandler, getRequestURL } from "h3";
import { loadIndex, loadSettings, saveSettings } from "../lib/storage";
import { nextCronTimeUtc } from "../lib/schedule";
import { pickPhoto } from "../lib/shuffle";

export default defineEventHandler(async (event) => {
  const [index, settings] = await Promise.all([loadIndex(), loadSettings()]);
  const nextCronTime = nextCronTimeUtc(settings.intervalHours);

  const pick = pickPhoto(index, settings);
  if (!pick) {
    return {
      status: 204,
      message: "No image available",
      data: {
        next_cron_time: nextCronTime
      }
    };
  }

  if (pick.settings.cursor !== settings.cursor) {
    await saveSettings(pick.settings);
  }

  const origin = getRequestURL(event).origin;
  const imageUrl = `${origin}/images/${encodeURIComponent(pick.photo.file)}`;

  return {
    status: 200,
    type: "SHOW",
    message: "Image retrieved successfully",
    data: {
      next_cron_time: nextCronTime,
      image_url: imageUrl
    }
  };
});
