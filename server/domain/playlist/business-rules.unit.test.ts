import { describe, expect, test } from 'bun:test'
import type { ImageId } from '~/domain/image/types'
import { applyQuietHours, pickRandomImageId } from './business-rules'
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
})
