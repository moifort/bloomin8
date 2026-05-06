import { describe, expect, test } from 'bun:test'
import {
  DEFAULT_PLAYLIST_ID,
  PlaylistId,
  QuietHourEnd,
  QuietHourStart,
  randomPlaylistId,
  Timezone,
} from './primitives'

describe('PlaylistId', () => {
  test('accepts a valid UUID', () => {
    expect(PlaylistId('8d0fc632-378b-4fac-903c-96b4feb7d1c4')).toBe(
      '8d0fc632-378b-4fac-903c-96b4feb7d1c4' as never,
    )
  })

  test('rejects invalid UUIDs', () => {
    expect(() => PlaylistId('not-a-uuid')).toThrow()
  })

  test('randomPlaylistId produces a valid UUID', () => {
    expect(randomPlaylistId()).toMatch(/^[0-9a-f-]{36}$/)
  })

  test('DEFAULT_PLAYLIST_ID is the canonical mono-playlist UUID', () => {
    expect(DEFAULT_PLAYLIST_ID).toBe('8d0fc632-378b-4fac-903c-96b4feb7d1c4' as never)
  })
})

describe('Timezone', () => {
  test('accepts a valid IANA timezone', () => {
    expect(Timezone('Europe/Paris')).toBe('Europe/Paris' as never)
  })

  test('rejects unknown timezones', () => {
    expect(() => Timezone('Mars/Phobos')).toThrow()
  })
})

describe('QuietHourStart and QuietHourEnd', () => {
  test('accept integers in [0, 23]', () => {
    expect(QuietHourStart(0)).toBe(0 as never)
    expect(QuietHourStart(23)).toBe(23 as never)
    expect(QuietHourEnd(7)).toBe(7 as never)
  })

  test('reject values outside [0, 23]', () => {
    expect(() => QuietHourStart(-1)).toThrow()
    expect(() => QuietHourEnd(24)).toThrow()
  })

  test('reject floats', () => {
    expect(() => QuietHourStart(7.5)).toThrow()
  })
})
