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

// Only ids of images that still exist count: deleted images drop out of the
// cycle, fresh uploads join it as not-yet-shown.
export const countDisplayed = (allImagesId: ImageId[], shownImagesId: ImageId[]): number => {
  const shown = new Set(shownImagesId)
  return allImagesId.filter((id) => shown.has(id)).length
}

// Converts the pre-`shownImagesId` storage (ids still to show) into the shown
// ids, so a server upgrade keeps the current cycle where it was.
export const shownFromRemaining = (allImagesId: ImageId[], remainingImagesId: ImageId[]) => {
  const remaining = new Set(remainingImagesId)
  return allImagesId.filter((id) => !remaining.has(id))
}

// Picks the next image of the current cycle. Once every existing image has been
// shown, a new cycle starts without repeating the last displayed image.
// Returns null when there is no image at all.
export const pickNextImage = (input: {
  allImagesId: ImageId[]
  shownImagesId: ImageId[]
  lastImageId?: ImageId
}): { nextImageId: ImageId; shownImagesId: ImageId[] } | null => {
  const { allImagesId, lastImageId } = input
  if (allImagesId.length === 0) return null
  const shown = new Set(input.shownImagesId)
  const stillShown = allImagesId.filter((id) => shown.has(id))
  const remaining = allImagesId.filter((id) => !shown.has(id))
  const isNewCycle = remaining.length === 0
  const nextImageId = isNewCycle
    ? pickRandomImageId(allImagesId, lastImageId)
    : pickRandomImageId(remaining)
  return { nextImageId, shownImagesId: [...(isNewCycle ? [] : stillShown), nextImageId] }
}

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
