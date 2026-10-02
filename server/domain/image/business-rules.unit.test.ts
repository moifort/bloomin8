import { describe, expect, test } from 'bun:test'
import type { ImageId } from '~/domain/image/types'
import { imagesToDeleteForKeeping } from './business-rules'

const ids = (values: string[]) => values as unknown as ImageId[]

describe('imagesToDeleteForKeeping', () => {
  test('deletes every image that is not kept', () => {
    expect(imagesToDeleteForKeeping(ids(['old1', 'old2', 'new1']), ids(['new1']))).toEqual(
      ids(['old1', 'old2']),
    )
  })

  test('ignores kept ids that do not exist', () => {
    expect(imagesToDeleteForKeeping(ids(['old', 'new']), ids(['new', 'ghost']))).toEqual(
      ids(['old']),
    )
  })

  test('deletes nothing when everything is kept', () => {
    expect(imagesToDeleteForKeeping(ids(['a', 'b']), ids(['a', 'b']))).toEqual([])
  })

  test('refuses when no kept id exists, instead of wiping the album', () => {
    expect(imagesToDeleteForKeeping(ids(['old1', 'old2']), ids(['ghost']))).toBeNull()
    expect(imagesToDeleteForKeeping(ids(['old1']), [])).toBeNull()
  })
})
