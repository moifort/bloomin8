import { describe, expect, test } from 'bun:test'
import {
  ImageId,
  ImageOrientation,
  ImageRaw,
  ImageUrl,
  MAX_IMAGE_BYTES,
  randomImageId,
} from './primitives'

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
  const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10])

  test('keeps a JPEG Buffer as-is', () => {
    expect(ImageRaw(jpeg)).toBe(jpeg as never)
  })

  test('decodes the legacy base64 string form', () => {
    expect(ImageRaw(jpeg.toString('base64')).equals(jpeg)).toBe(true)
  })

  test('rejects empty input', () => {
    expect(() => ImageRaw('')).toThrow()
    expect(() => ImageRaw(Buffer.alloc(0))).toThrow()
  })

  test('rejects bytes that are not a JPEG', () => {
    expect(() => ImageRaw(Buffer.from('hello'))).toThrow('Image must be a JPEG')
    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a])
    expect(() => ImageRaw(png)).toThrow('Image must be a JPEG')
    expect(() => ImageRaw(Buffer.from('hello').toString('base64'))).toThrow()
  })

  test('accepts up to MAX_IMAGE_BYTES and rejects anything larger', () => {
    const atLimit = Buffer.alloc(MAX_IMAGE_BYTES)
    jpeg.copy(atLimit)
    expect(ImageRaw(atLimit).length).toBe(MAX_IMAGE_BYTES)

    const tooLarge = Buffer.alloc(MAX_IMAGE_BYTES + 1)
    jpeg.copy(tooLarge)
    expect(() => ImageRaw(tooLarge)).toThrow('Image must not exceed 10 MB')
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
