export default defineNitroConfig({
  compatibilityDate: '2026-02-06',
  srcDir: 'server',
  rollupConfig: {
    treeshake: {
      moduleSideEffects: (id) => id.includes('/graphql/') || id.includes('node_modules'),
    },
  },
  runtimeConfig: {
    serverUrl: 'http://192.168.0.164:3000',
    homekit: {
      // Overridable via NITRO_HOMEKIT_PINCODE / _USERNAME / _PORT.
      pincode: '031-45-154',
      username: 'CA:11:A5:00:00:01', // valid hex MAC required by hap-nodejs
      port: 47129,
    },
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
