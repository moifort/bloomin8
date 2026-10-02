import { createLogger } from '~/system/logger'

const log = createLogger('startup')

// Nitro does not await async plugins before serving requests: without this
// gate a device pull could run against half-migrated storage (and, for the
// playlist, overwrite the legacy cycle before it is converted).
let pending: Promise<void> = Promise.resolve()

export const runMigrations = (migrate: () => Promise<void>) => {
  // A failed migration is logged and the server keeps serving: blocking every
  // request forever would be worse than a partially migrated store.
  pending = migrate().catch((error) => log.error('Startup migration failed', error))
}

export const migrationsDone = () => pending
