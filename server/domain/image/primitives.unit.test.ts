import { describe, expect, test } from 'bun:test'
import { ImageId, ImageOrientation, ImageRaw, ImageUrl, randomImageId } from './primitives'

describe('ImageId', () => {
  test('accepts a valid UUID', () => {
    const id = '8d0fc632-378b-4fac-903c-96b4feb7d1c4'
    expect(ImageId(id)).toBe(id as never)
  })

  test('rejects malformed strings', () => {
    expect(() => ImageId('not-a-uuid')).toThrow()
    expect(() => ImageId(123)).toThrow()
  })

  test('randomImageId produces a valid UUID', () => {
    const id = randomImageId()
    expect(typeof id).toBe('string')
    expect(id).toMatch(/^[0-9a-f-]{36}$/)
  })
})

describe('ImageUrl', () => {
  test('accepts a path starting with /', () => {
    expect(ImageUrl('/images/foo.jpg')).toBe('/images/foo.jpg' as never)
  })

  test('rejects paths without leading slash', () => {
    expect(() => ImageUrl('images/foo.jpg')).toThrow()
  })
})

describe('ImageRaw', () => {
  test('accepts a non-empty string', () => {
    expect(ImageRaw('abc')).toBe('abc' as never)
  })

  test('encodes a Buffer to base64', () => {
    const result = ImageRaw(Buffer.from('hello'))
    expect(result).toBe(Buffer.from('hello').toString('base64') as never)
  })

  test('rejects empty strings', () => {
    expect(() => ImageRaw('')).toThrow()
  })
})

describe('ImageOrientation', () => {
  test('accepts P and L', () => {
    expect(ImageOrientation('P')).toBe('P' as never)
    expect(ImageOrientation('L')).toBe('L' as never)
  })

  test('rejects other values', () => {
    expect(() => ImageOrientation('X')).toThrow()
    expect(() => ImageOrientation('p')).toThrow()
  })
})
