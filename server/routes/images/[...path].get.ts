export default eventHandler(async (event) => {
    const path = getRouterParam(event, 'path')
    setResponseHeader(event, 'content-type', 'image/jpeg')
    return file
})
