import { createStorage, type Storage } from 'unstorage'
import memoryDriver from 'unstorage/drivers/memory'

// Integration tests run the domain commands outside Nitro: install an
// in-memory `useStorage` with one storage per bucket name, as Nitro does.
const buckets = new Map<string, Storage>()

;(globalThis as { useStorage?: unknown }).useStorage = (base: string) => {
  let bucket = buckets.get(base)
  if (!bucket) {
    bucket = createStorage({ driver: memoryDriver() })
    buckets.set(base, bucket)
  }
  return bucket
}

export const resetMemoryStorage = () => buckets.clear()
