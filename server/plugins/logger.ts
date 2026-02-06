export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('request', (event) => {
    console.log(`${new Date().toISOString()} on request `, event.path)
  })
  nitroApp.hooks.hook('beforeResponse', (event, { body }) => {
    console.log(`${new Date().toISOString()} on response`, event.path, { body })
  })

  nitroApp.hooks.hook('afterResponse', (event, response) => {
    console.log(`${new Date().toISOString()} on after response`, event.path, {
      body: response?.body,
    })
  })
})
