export default eventHandler(() => ({
  status: 200,
  service: 'bloomin8-eink-pull',
  endpoints: [
    'GET /eink_pull',
    'POST /upload?filename=photo_P.jpg',
    'GET /images/:filename',
    'GET /settings',
    'PUT /settings',
  ],
}))
