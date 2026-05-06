import { describe, expect, test } from 'bun:test'
import { batteryUpdate } from './business-rules'
import { Percentage } from './primitives'

describe('batteryUpdate', () => {
  test('records lastPullDate on every update', () => {
    const now = new Date('2026-01-01T12:00:00Z')
    const result = batteryUpdate({ previous: null, level: Percentage(50), now })
    expect(result.lastPullDate).toEqual(now)
    expect(result.percentage).toBe(50 as never)
  })

  test('initializes lastFullChargeDate to null when never fully charged', () => {
    const result = batteryUpdate({
      previous: null,
      level: Percentage(80),
      now: new Date('2026-01-01T12:00:00Z'),
    })
    expect(result.lastFullChargeDate).toBeNull()
  })

  test('sets lastFullChargeDate when crossing to 100% from below', () => {
    const previous = {
      percentage: Percentage(80),
      lastFullChargeDate: null,
      lastPullDate: new Date('2026-01-01T11:00:00Z'),
    }
    const now = new Date('2026-01-01T12:00:00Z')
    const result = batteryUpdate({ previous, level: Percentage(100), now })
    expect(result.lastFullChargeDate).toEqual(now)
  })

  test('preserves lastFullChargeDate when already at 100%', () => {
    const fullChargedAt = new Date('2025-12-31T10:00:00Z')
    const previous = {
      percentage: Percentage(100),
      lastFullChargeDate: fullChargedAt,
      lastPullDate: new Date('2026-01-01T11:00:00Z'),
    }
    const now = new Date('2026-01-01T12:00:00Z')
    const result = batteryUpdate({ previous, level: Percentage(100), now })
    expect(result.lastFullChargeDate).toEqual(fullChargedAt)
  })

  test('preserves the previous lastFullChargeDate when battery drops', () => {
    const fullChargedAt = new Date('2025-12-31T10:00:00Z')
    const previous = {
      percentage: Percentage(100),
      lastFullChargeDate: fullChargedAt,
      lastPullDate: new Date('2026-01-01T11:00:00Z'),
    }
    const result = batteryUpdate({
      previous,
      level: Percentage(80),
      now: new Date('2026-01-01T12:00:00Z'),
    })
    expect(result.lastFullChargeDate).toEqual(fullChargedAt)
  })
})
