export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  runtimeConfig: {
    canvasUrl: process.env.CANVAS_URL ?? 'http://192.168.0.174',
    serverUrl: process.env.SERVER_URL ?? 'http://192.168.0.164:3000',
    cronIntervalInHours: process.env.CRON_INTERVAL_IN_HOURS ?? '3',
  },
  storage: {
    images: {
      driver: 'fs',
      base: './data/images',
    },
    playlist: {
      driver: 'fs',
      base: './data/playlist',
    },
  },
  routeRules: {
    '/images/**': {
      headers: {
        'cache-control': 'public, max-age=31536000, immutable',
      },
    },
  },
})
