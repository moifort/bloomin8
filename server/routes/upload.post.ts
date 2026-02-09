export default eventHandler(async (event) => {
    const query = getQuery(event)
    return {status: 200, message: 'Uploaded'}
})
