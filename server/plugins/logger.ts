import { consola } from 'consola'

const log = consola.withTag('http')

// One line per request. Bodies are not logged: image responses are megabytes
// of binary and GraphQL errors are already reported by the /graphql route.
export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('request', (event) => {
    event.context.startedAt = performance.now()
  })
  nitroApp.hooks.hook('afterResponse', (event) => {
    if (event.path === '/health') return
    const durationMs = Math.round(
      performance.now() - (event.context.startedAt ?? performance.now()),
    )
    log.info(`${event.method} ${event.path} → ${event.node.res.statusCode} (${durationMs} ms)`)
  })
  nitroApp.hooks.hook('error', (error) => {
    log.error('on error', error)
  })
})
