export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  runtimeConfig: {
    serverUrl: 'http://192.168.0.164:3000',
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
    canvas: {
      driver: 'fs',
      base: './data/canvas',
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
