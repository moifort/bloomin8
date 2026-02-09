export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  storage: {
    images: {
      driver: 'fs',
      base: './data/images',
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
