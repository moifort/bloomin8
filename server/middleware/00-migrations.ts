import { migrationsDone } from '~/system/migrations'

// Runs before every other middleware (files are applied in name order).
// /health stays immediate so the container healthcheck passes during a long
// migration.
export default defineEventHandler(async (event) => {
  if (event.path === '/health') return
  await migrationsDone()
})
