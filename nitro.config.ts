export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  runtimeConfig: {
    canvasUrl: 'http://192.168.0.174',
    serverUrl: 'http://192.168.0.164:3000',
    cronIntervalInHours: '3',
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
