import type { Battery, Percentage } from '~/domain/canvas/types'

export const batteryUpdate = (input: {
  previous: Battery | null
  level: Percentage
  now: Date
}): Battery => {
  const { previous, level, now } = input
  const previousPercentage = previous?.percentage ?? 0
  const isFullyCharged = level === 100 && previousPercentage < 100
  return {
    percentage: level,
    lastFullChargeDate: isFullyCharged ? now : (previous?.lastFullChargeDate ?? null),
    lastPullDate: now,
  }
}
