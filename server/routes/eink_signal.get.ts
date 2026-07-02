import { createLogger } from '~/system/logger'

const log = createLogger('canvas')

// Device feedback is acknowledged and logged, but intentionally not persisted yet.
export default defineEventHandler(async (event) => {
  const { pull_id, success } = getQuery(event)
  log.info('Device signal received', { pull_id, success })
  return { status: 200, message: 'Feedback recorded' }
})
