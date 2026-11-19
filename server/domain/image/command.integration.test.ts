import { beforeEach, describe, expect, test } from 'bun:test'
import { ImageCommand } from '~/domain/image/command'
import { ImageId, ImageOrientation, ImageRaw } from '~/domain/image/primitives'
import { ImageQuery } from '~/domain/image/query'
import { resetMemoryStorage } from '~/testing/memory-storage'

const jpeg = ImageRaw(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00]))

const uploadImages = async (count: number) => {
  const ids = []
  for (let index = 0; index < count; index++) {
    ids.push((await ImageCommand.save(jpeg, ImageOrientation('P'))).id)
  }
  return ids
}

const sorted = <T>(values: T[]) => [...values].sort()

beforeEach(() => resetMemoryStorage())

describe('ImageCommand.save', () => {
  test('stores the metadata and the JPEG file', async () => {
    const [id] = await uploadImages(1)
    if (!id) throw new Error('no image')
    expect(await ImageQuery.findById(id)).toMatchObject({ id, orientation: 'P' })
    expect(await ImageQuery.findFileByName(`${id}_P.jpg`)).toEqual(jpeg)
  })
})

describe('ImageCommand.keepOnly', () => {
  test('drops every image except the kept ones, files included', async () => {
    const oldAlbum = await uploadImages(3)
    const newAlbum = await uploadImages(2)

    expect(await ImageCommand.keepOnly(newAlbum)).toBe(3)

    expect(sorted(await ImageQuery.findAllIds())).toEqual(sorted(newAlbum))
    for (const id of oldAlbum) {
      expect(await ImageQuery.findById(id)).toBeNull()
      expect(await ImageQuery.findFileByName(`${id}_P.jpg`)).toBeNull()
    }
  })

  test('refuses to wipe the album when none of the kept ids exists', async () => {
    const album = await uploadImages(2)
    expect(await ImageCommand.keepOnly([ImageId(crypto.randomUUID())])).toBe('no-kept-image')
    expect(sorted(await ImageQuery.findAllIds())).toEqual(sorted(album))
  })
})

describe('ImageCommand.deleteMany', () => {
  test('deletes the given images and ignores unknown ids', async () => {
    const [kept, ...cancelled] = await uploadImages(3)
    const unknown = ImageId(crypto.randomUUID())

    expect(await ImageCommand.deleteMany([...cancelled, unknown])).toBe(2)
    expect(await ImageQuery.findAllIds()).toEqual(kept ? [kept] : [])
  })
})
