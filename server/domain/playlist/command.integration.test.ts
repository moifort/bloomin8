import { afterEach, beforeAll, beforeEach, describe, expect, spyOn, test } from 'bun:test'
import { consola } from 'consola'
import { CanvasUrl, ServerUrl } from '~/domain/config/primitives'
import { ImageCommand } from '~/domain/image/command'
import { ImageOrientation, ImageRaw } from '~/domain/image/primitives'
import { ImageQuery } from '~/domain/image/query'
import { PlaylistCommand } from '~/domain/playlist/command'
import { QuietHourEnd, QuietHourStart, Timezone } from '~/domain/playlist/primitives'
import { PlaylistQuery } from '~/domain/playlist/query'
import { Hour } from '~/domain/shared/primitives'
import { resetMemoryStorage } from '~/testing/memory-storage'

const jpeg = ImageRaw(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00]))
const serverUrl = ServerUrl('http://server.test:3000')
const canvasUrl = CanvasUrl('http://canvas.test')
const quietHours = {
  enabled: true,
  timezone: Timezone('Europe/Paris'),
  start: QuietHourStart(23),
  end: QuietHourEnd(7),
}

const uploadImages = async (count: number) => {
  const images = []
  for (let index = 0; index < count; index++) {
    images.push(await ImageCommand.save(jpeg, ImageOrientation('P')))
  }
  return images.map((image) => image.id)
}

const start = () => PlaylistCommand.start(serverUrl, canvasUrl, Hour(3))

// The unreachable-Canvas warnings are expected here.
beforeAll(() => {
  consola.level = 0
})

beforeEach(() => {
  resetMemoryStorage()
  // The Canvas is never reachable from tests: start/resume must cope with it.
  spyOn(globalThis, 'fetch').mockRejectedValue(new Error('canvas offline'))
})

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore: () => void }).mockRestore()
})

describe('PlaylistCommand.start', () => {
  test('refuses to start without any image', async () => {
    expect(await start()).toBe('playlist-empty')
  })

  test('starts even when the Canvas does not answer', async () => {
    await uploadImages(1)
    const result = await start()
    expect(result).toMatchObject({ wokeUp: false })
  })

  test('keeps the image on display and the existing quiet hours on restart', async () => {
    await uploadImages(2)
    await PlaylistCommand.start(serverUrl, canvasUrl, Hour(3), quietHours)
    const shown = await PlaylistCommand.nextImage()
    if (shown === 'playlist-not-found' || shown.kind !== 'show')
      throw new Error('expected an image')

    await start()

    const progress = await PlaylistQuery.findById()
    expect(progress?.lastImageId).toBe(shown.image.id)
    expect(progress?.quietHours).toEqual(quietHours)
    expect(progress?.shownImagesId).toEqual([])
  })
})

describe('PlaylistCommand.nextImage', () => {
  test('answers playlist-not-found before any start', async () => {
    expect(await PlaylistCommand.nextImage()).toBe('playlist-not-found')
  })

  test('shows every image once per cycle, then starts a new cycle', async () => {
    const ids = await uploadImages(3)
    await start()

    const firstCycle = []
    for (let pull = 0; pull < 3; pull++) {
      const outcome = await PlaylistCommand.nextImage()
      if (outcome === 'playlist-not-found' || outcome.kind !== 'show') throw new Error('no image')
      firstCycle.push(outcome.image.id)
    }
    expect([...firstCycle].sort()).toEqual([...ids].sort())

    const refill = await PlaylistCommand.nextImage()
    if (refill === 'playlist-not-found' || refill.kind !== 'show') throw new Error('no image')
    // A new cycle never repeats the image that was just displayed.
    expect(refill.image.id).not.toBe(firstCycle[2])
    expect((await PlaylistQuery.findById())?.shownImagesId).toEqual([refill.image.id])
  })

  test('schedules the next pull one interval later', async () => {
    await uploadImages(1)
    await start()
    const before = Date.now()
    const outcome = await PlaylistCommand.nextImage()
    if (outcome === 'playlist-not-found') throw new Error('no playlist')
    const delay = outcome.nextPullAt.getTime() - before
    expect(delay).toBeGreaterThanOrEqual(3 * 60 * 60 * 1000 - 1000)
    expect(delay).toBeLessThanOrEqual(3 * 60 * 60 * 1000 + 1000)
    expect((await PlaylistQuery.findById())?.nextPullAt).toEqual(outcome.nextPullAt)
  })

  test('answers empty when the picked image was deleted after listing', async () => {
    await uploadImages(1)
    await start()
    const findById = spyOn(ImageQuery, 'findById').mockResolvedValueOnce(null)
    const outcome = await PlaylistCommand.nextImage()
    findById.mockRestore()
    expect(outcome).toMatchObject({ kind: 'empty' })
    expect((await PlaylistQuery.findById())?.shownImagesId).toEqual([])
  })

  test('answers empty once every image is gone', async () => {
    const ids = await uploadImages(1)
    await start()
    await ImageCommand.deleteMany(ids)
    expect(await PlaylistCommand.nextImage()).toMatchObject({ kind: 'empty' })
  })

  test('shows nothing while paused, then resumes the cycle', async () => {
    await uploadImages(2)
    await start()
    expect(await PlaylistCommand.pause()).not.toBe('not-playing')
    expect(await PlaylistCommand.pause()).toBe('not-playing')

    const paused = await PlaylistCommand.nextImage()
    expect(paused).toMatchObject({ kind: 'paused' })
    expect((await PlaylistQuery.findById())?.shownImagesId).toEqual([])

    expect(await PlaylistCommand.resume(serverUrl)).toMatchObject({ wokeUp: false })
    expect(await PlaylistCommand.nextImage()).toMatchObject({ kind: 'show' })
  })
})
