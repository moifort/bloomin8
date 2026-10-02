export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  rollupConfig: {
    treeshake: {
      moduleSideEffects: (id) => id.includes('/graphql/') || id.includes('node_modules'),
    },
  },
  runtimeConfig: {
    serverUrl: 'http://192.168.1.199:3000',
  },
  storage: {
    images: {
      driver: 'fs',
      base: './data/images',
    },
    'image-files': {
      driver: 'fs',
      base: './data/image-files',
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
