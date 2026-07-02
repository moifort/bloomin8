import { describe, expect, test } from 'bun:test'
import type { ImageId } from '~/domain/image/types'
import { applyQuietHours, computeDisplayed, pickRandomImageId } from './business-rules'
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

describe('computeDisplayed', () => {
  test('returns the number of already displayed images', () => {
    expect(computeDisplayed(10, 4)).toBe(6)
  })

  test('clamps to zero when remaining exceeds total (images deleted mid-cycle)', () => {
    expect(computeDisplayed(4, 10)).toBe(0)
  })

  test('caps at total when nothing remains', () => {
    expect(computeDisplayed(5, 0)).toBe(5)
  })

  test('returns zero when there are no images', () => {
    expect(computeDisplayed(0, 0)).toBe(0)
  })
})
