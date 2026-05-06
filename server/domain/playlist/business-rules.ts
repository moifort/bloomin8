import type { ImageId } from '~/domain/image/types'
import type { QuietHours } from '~/domain/playlist/types'

export const applyQuietHours = (date: Date, quietHours?: QuietHours): Date => {
  if (!quietHours?.enabled) return date

  const { timezone, start, end } = quietHours

  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  }).formatToParts(date)

  const hour = Number.parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10)
  const minute = Number.parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10)

  if (hour >= end && hour < start) return date

  const hoursUntilEnd = hour >= start ? 24 - hour + end : end - hour
  const msUntilEnd = (hoursUntilEnd * 60 - minute) * 60 * 1000

  return new Date(date.getTime() + msUntilEnd)
}

export const pickRandomImageId = (availableImagesId: ImageId[]): ImageId => {
  if (availableImagesId.length === 0) throw new Error('availableImagesId must not be empty')
  if (availableImagesId.length === 1) return availableImagesId[0] as ImageId
  const randomIndex = Math.floor(Math.random() * availableImagesId.length)
  return availableImagesId[randomIndex] as ImageId
}
