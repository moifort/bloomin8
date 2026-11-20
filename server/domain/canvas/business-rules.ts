import type { Battery, Percentage } from '~/domain/canvas/types'
import type { ServerUrl } from '~/domain/config/types'

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

// The device keeps the upstream address it was given at its last wake-up. When
// it reached us through another address (an old server, a relay), its stored
// upstream is outdated and must be repointed at the configured server URL.
export const isUpstreamOutdated = (input: {
  pulledVia: string | null
  serverUrl: ServerUrl
}): boolean => {
  const { pulledVia, serverUrl } = input
  if (!pulledVia) return false
  return pulledVia.toLowerCase() !== new URL(serverUrl).host.toLowerCase()
}
