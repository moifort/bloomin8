import type { PhotoEntry } from '../domain/model'
import { nextCronTimeUtc } from '../domain/schedule'
import { pickPhoto } from '../domain/selection'
import { loadIndex, loadSettings, saveSettings } from '../infrastructure/storage'

export type PullEinkResult =
  | { kind: 'empty'; nextCronTime: string }
  | { kind: 'photo'; nextCronTime: string; photo: PhotoEntry }

export const pullEink = async (nowMs = Date.now()): Promise<PullEinkResult> => {
  const [index, settings] = await Promise.all([loadIndex(), loadSettings()])
  const nextCronTime = nextCronTimeUtc(settings.intervalHours, nowMs)

  const pick = pickPhoto(index, settings)
  if (!pick) {
    return { kind: 'empty', nextCronTime }
  }

  if (pick.settings.cursor !== settings.cursor) {
    await saveSettings(pick.settings)
  }

  return {
    kind: 'photo',
    nextCronTime,
    photo: pick.photo,
  }
}
