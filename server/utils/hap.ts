import type { Accessory } from 'hap-nodejs'

let instance: Accessory | null = null

export const setHapBridge = (accessory: Accessory) => {
  instance = accessory
}

// Best-effort accessor — returns null until the HAP plugin has published.
// Callers (e.g. future proactive characteristic pushes) must handle null.
export const useHapBridge = () => instance
