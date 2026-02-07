import { describe, expect, it } from 'bun:test'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'

const baseUrl = process.env.TEST_BASE_URL ?? 'http://localhost:3000'
const imagePath = process.env.TEST_IMAGE_PATH ?? join(process.cwd(), 'tests', 'data', 'test.jpeg')

describe('upload', () => {
  it('uploads a jpeg via raw body', async () => {
    const jpegBytes = await readFile(imagePath)
    const res = await fetch(`${baseUrl}/upload?orientation=P`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/octet-stream' },
      body: jpegBytes,
    })

    expect(res.status).toBe(200)
    const json = await res.json()
    expect(json.status).toBe(200)
    expect(typeof json.data.file).toBe('string')
    expect(json.data.file).toMatch(/^[a-f0-9]{24}_P\.jpg$/)
  })

  it('deletes all photos', async () => {
    const jpegBytes = await readFile(imagePath)
    const uploadRes = await fetch(`${baseUrl}/upload?orientation=P`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/octet-stream' },
      body: jpegBytes,
    })

    expect(uploadRes.status).toBe(200)
    const uploadJson = await uploadRes.json()
    const fileName = uploadJson?.data?.file
    expect(typeof fileName).toBe('string')

    const deleteRes = await fetch(`${baseUrl}/photos`, {
      method: 'DELETE',
    })

    expect(deleteRes.status).toBe(200)
    const deleteJson = await deleteRes.json()
    expect(deleteJson.status).toBe(200)
    expect(typeof deleteJson.data.deletedFiles).toBe('number')
    expect(deleteJson.data.deletedFiles).toBeGreaterThanOrEqual(1)

    const imageRes = await fetch(`${baseUrl}/images/${encodeURIComponent(fileName)}`)
    expect(imageRes.status).toBe(404)

    const pullRes = await fetch(`${baseUrl}/eink_pull`)
    expect(pullRes.status).toBe(200)
    const pullJson = await pullRes.json()
    expect(pullJson.status).toBe(204)
  })
})
