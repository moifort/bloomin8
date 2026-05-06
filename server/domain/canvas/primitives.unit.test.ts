import { describe, expect, test } from 'bun:test'
import { CanvasDate, Percentage } from './primitives'

describe('Percentage', () => {
  test('accepts integers in [0, 100]', () => {
    expect(Percentage(0)).toBe(0 as never)
    expect(Percentage(50)).toBe(50 as never)
    expect(Percentage(100)).toBe(100 as never)
  })

  test('coerces numeric strings', () => {
    expect(Percentage('80')).toBe(80 as never)
  })

  test('rejects values outside [0, 100]', () => {
    expect(() => Percentage(-1)).toThrow()
    expect(() => Percentage(101)).toThrow()
  })

  test('rejects floats', () => {
    expect(() => Percentage(50.5)).toThrow()
  })
})

describe('CanvasDate', () => {
  test('serializes a Date to ISO 8601 without milliseconds', () => {
    const result = CanvasDate(new Date('2026-01-01T12:34:56.789Z'))
    expect(result).toBe('2026-01-01T12:34:56Z' as never)
  })

  test('rejects non-Date values', () => {
    expect(() => CanvasDate('2026-01-01')).toThrow()
  })
})
