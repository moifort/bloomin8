export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('request', (event) => {
    console.log(`${new Date().toISOString()} on request `, event.path)
  })
  nitroApp.hooks.hook('beforeResponse', (event, { body }) => {
    console.log(`${new Date().toISOString()} on response`, event.path, { body })
  })
  nitroApp.hooks.hook('error', (error) => {
    console.error(`${new Date().toISOString()} on error`, error)
  })
})
