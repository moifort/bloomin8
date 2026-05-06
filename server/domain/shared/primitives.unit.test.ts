import { describe, expect, test } from 'bun:test'
import { Hour } from './primitives'

describe('Hour', () => {
  test('accepts integer in [1, 168]', () => {
    expect(Hour(1)).toBe(1 as never)
    expect(Hour(24)).toBe(24 as never)
    expect(Hour(168)).toBe(168 as never)
  })

  test('coerces numeric strings', () => {
    expect(Hour('12')).toBe(12 as never)
  })

  test('rejects values outside [1, 168]', () => {
    expect(() => Hour(0)).toThrow()
    expect(() => Hour(169)).toThrow()
  })

  test('rejects non-integers', () => {
    expect(() => Hour(1.5)).toThrow()
  })

  test('rejects non-numeric values', () => {
    expect(() => Hour('abc')).toThrow()
    expect(() => Hour(null)).toThrow()
  })
})
