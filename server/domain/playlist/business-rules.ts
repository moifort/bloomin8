import type { ImageId } from '~/domain/image/types'
import type { QuietHours } from '~/domain/playlist/types'

// Shifts a date falling inside the quiet window to the window's end hour, in the
// playlist timezone. Supports both orientations: start > end crosses midnight
// (23h–7h), start < end stays within one day (9h–17h). start === end means no window.
export const applyQuietHours = (date: Date, quietHours?: QuietHours): Date => {
  if (!quietHours?.enabled) return date

  const { timezone, start, end } = quietHours
  if (Number(start) === Number(end)) return date

  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  }).formatToParts(date)

  const hour = Number.parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10)
  const minute = Number.parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10)

  const inQuietWindow = start < end ? hour >= start && hour < end : hour >= start || hour < end
  if (!inQuietWindow) return date

  const hoursUntilEnd = (end - hour + 24) % 24
  const msUntilEnd = (hoursUntilEnd * 60 - minute) * 60 * 1000

  return new Date(date.getTime() + msUntilEnd)
}

export const computeDisplayed = (total: number, remaining: number): number =>
  Math.min(total, Math.max(0, total - remaining))

// `exclude` avoids showing the same image twice in a row across a cycle refill;
// it is ignored when it would leave nothing to pick from.
export const pickRandomImageId = (availableImagesId: ImageId[], exclude?: ImageId): ImageId => {
  if (availableImagesId.length === 0) throw new Error('availableImagesId must not be empty')
  const candidates =
    availableImagesId.length > 1
      ? availableImagesId.filter((id) => id !== exclude)
      : availableImagesId
  if (candidates.length === 1) return candidates[0] as ImageId
  const randomIndex = Math.floor(Math.random() * candidates.length)
  return candidates[randomIndex] as ImageId
}
