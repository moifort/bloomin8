import { describe, expect, test } from 'bun:test'
import type { ImageId } from '~/domain/image/types'
import {
  applyQuietHours,
  countDisplayed,
  pickNextImage,
  pickRandomImageId,
  shownFromRemaining,
} from './business-rules'
import { QuietHourEnd, QuietHourStart, Timezone } from './primitives'

const ids = (values: string[]) => values as unknown as ImageId[]

describe('pickRandomImageId', () => {
  test('returns the only id when array has one element', () => {
    const id = ids(['only-id'])[0] as ImageId
    expect(pickRandomImageId([id])).toBe(id)
  })

  test('returns one of the ids when array has many', () => {
    const list = ids(['a', 'b', 'c'])
    expect(list).toContain(pickRandomImageId(list))
  })

  test('throws when the array is empty', () => {
    expect(() => pickRandomImageId([])).toThrow()
  })

  test('never picks the excluded id when others are available', () => {
    const list = ids(['a', 'b', 'c'])
    const excluded = list[0] as ImageId
    for (let i = 0; i < 50; i++) {
      expect(pickRandomImageId(list, excluded)).not.toBe(excluded)
    }
  })

  test('ignores the exclusion when it is the only id left', () => {
    const only = ids(['a'])[0] as ImageId
    expect(pickRandomImageId([only], only)).toBe(only)
  })
})

describe('applyQuietHours', () => {
  const tz = Timezone('UTC')
  const start = QuietHourStart(23)
  const end = QuietHourEnd(7)

  test('returns the input date unchanged when quietHours is disabled', () => {
    const input = new Date('2026-01-01T12:00:00Z')
    expect(applyQuietHours(input, { enabled: false, timezone: tz, start, end })).toEqual(input)
  })

  test('returns the input date unchanged when quietHours is undefined', () => {
    const input = new Date('2026-01-01T12:00:00Z')
    expect(applyQuietHours(input, undefined)).toEqual(input)
  })

  test('shifts a date inside the quiet window forward to the end hour', () => {
    // 02:00 UTC, quiet 23h–7h → wait until 07:00 UTC (5 h)
    const input = new Date('2026-01-01T02:00:00Z')
    const shifted = applyQuietHours(input, { enabled: true, timezone: tz, start, end })
    expect(shifted.getUTCHours()).toBe(7)
    expect(shifted.getUTCMinutes()).toBe(0)
  })

  test('leaves a date outside the quiet window unchanged', () => {
    // 12:00 UTC, quiet 23h–7h → unchanged
    const input = new Date('2026-01-01T12:00:00Z')
    const shifted = applyQuietHours(input, { enabled: true, timezone: tz, start, end })
    expect(shifted).toEqual(input)
  })

  test('accounts for minutes when shifting to the end hour', () => {
    // 02:30 UTC, quiet 23h–7h → wait until exactly 07:00 UTC
    const input = new Date('2026-01-01T02:30:00Z')
    const shifted = applyQuietHours(input, { enabled: true, timezone: tz, start, end })
    expect(shifted.getUTCHours()).toBe(7)
    expect(shifted.getUTCMinutes()).toBe(0)
  })

  test('shifts a date at the quiet window start hour', () => {
    // 23:00 UTC, quiet 23h–7h → wait until 07:00 UTC next day
    const input = new Date('2026-01-01T23:00:00Z')
    const shifted = applyQuietHours(input, { enabled: true, timezone: tz, start, end })
    expect(shifted.getUTCDate()).toBe(2)
    expect(shifted.getUTCHours()).toBe(7)
  })

  describe('non-midnight-crossing window (start < end)', () => {
    const dayStart = QuietHourStart(9)
    const dayEnd = QuietHourEnd(17)

    test('shifts a date inside the window to the end hour', () => {
      // 12:00 UTC, quiet 9h–17h → 17:00 UTC same day
      const input = new Date('2026-01-01T12:00:00Z')
      const shifted = applyQuietHours(input, {
        enabled: true,
        timezone: tz,
        start: dayStart,
        end: dayEnd,
      })
      expect(shifted.getUTCDate()).toBe(1)
      expect(shifted.getUTCHours()).toBe(17)
    })

    test('leaves a date before the window unchanged', () => {
      const input = new Date('2026-01-01T08:00:00Z')
      const shifted = applyQuietHours(input, {
        enabled: true,
        timezone: tz,
        start: dayStart,
        end: dayEnd,
      })
      expect(shifted).toEqual(input)
    })

    test('leaves a date after the window unchanged', () => {
      const input = new Date('2026-01-01T18:00:00Z')
      const shifted = applyQuietHours(input, {
        enabled: true,
        timezone: tz,
        start: dayStart,
        end: dayEnd,
      })
      expect(shifted).toEqual(input)
    })
  })

  test('treats start === end as no quiet window', () => {
    const input = new Date('2026-01-01T12:00:00Z')
    const shifted = applyQuietHours(input, {
      enabled: true,
      timezone: tz,
      start: QuietHourStart(12),
      end: QuietHourEnd(12),
    })
    expect(shifted).toEqual(input)
  })
})

describe('countDisplayed', () => {
  test('counts the shown images that still exist', () => {
    expect(countDisplayed(ids(['a', 'b', 'c', 'd']), ids(['a', 'b']))).toBe(2)
  })

  test('ignores shown ids whose image was deleted', () => {
    expect(countDisplayed(ids(['a', 'b']), ids(['a', 'x', 'y']))).toBe(1)
  })

  test('does not count fresh uploads as displayed', () => {
    // Regression: the former `total - remaining` formula reported 3/3 here.
    expect(countDisplayed(ids(['n1', 'n2', 'n3']), [])).toBe(0)
  })

  test('returns zero when there are no images', () => {
    expect(countDisplayed([], ids(['a']))).toBe(0)
  })
})

describe('pickNextImage', () => {
  test('returns null when there is no image', () => {
    expect(pickNextImage({ allImagesId: [], shownImagesId: ids(['a']) })).toBeNull()
  })

  test('picks among the images not shown yet and records it', () => {
    for (let i = 0; i < 20; i++) {
      const result = pickNextImage({ allImagesId: ids(['a', 'b', 'c']), shownImagesId: ids(['a']) })
      expect(['b', 'c']).toContain(result?.nextImageId as string)
      expect(result?.shownImagesId).toEqual(ids(['a', result?.nextImageId as string]))
    }
  })

  test('lets an image uploaded mid-cycle join the current cycle', () => {
    const result = pickNextImage({ allImagesId: ids(['a', 'new']), shownImagesId: ids(['a']) })
    expect(result?.nextImageId).toBe('new' as ImageId)
  })

  test('drops deleted ids from the shown list', () => {
    const result = pickNextImage({
      allImagesId: ids(['a', 'b']),
      shownImagesId: ids(['a', 'gone']),
    })
    expect(result).toEqual({ nextImageId: 'b' as ImageId, shownImagesId: ids(['a', 'b']) })
  })

  test('starts a new cycle without repeating the last image', () => {
    for (let i = 0; i < 20; i++) {
      const result = pickNextImage({
        allImagesId: ids(['a', 'b', 'c']),
        shownImagesId: ids(['a', 'b', 'c']),
        lastImageId: 'c' as ImageId,
      })
      expect(result?.nextImageId).not.toBe('c' as ImageId)
      expect(result?.shownImagesId).toEqual([result?.nextImageId as ImageId])
    }
  })

  test('repeats the only image when it is alone', () => {
    const result = pickNextImage({
      allImagesId: ids(['a']),
      shownImagesId: ids(['a']),
      lastImageId: 'a' as ImageId,
    })
    expect(result).toEqual({ nextImageId: 'a' as ImageId, shownImagesId: ids(['a']) })
  })
})

describe('shownFromRemaining', () => {
  test('keeps the cycle position of a legacy playlist', () => {
    expect(shownFromRemaining(ids(['a', 'b', 'c', 'd']), ids(['c', 'd']))).toEqual(ids(['a', 'b']))
  })

  test('ignores remaining ids whose image no longer exists', () => {
    expect(shownFromRemaining(ids(['a', 'b']), ids(['b', 'gone']))).toEqual(ids(['a']))
  })
})
