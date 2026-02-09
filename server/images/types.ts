import type { Brand } from 'ts-brand'

export type ImageId = Brand<string, 'ImageId'>
export type ImageRaw = Brand<string, 'ImageRaw'>
export type ImageUrl = Brand<string, 'ImageUrl'>
export type ImageOrientation = Brand<'P' | 'L', 'ImageOrientation'>
export type Image = {
  id: ImageId
  orientation: ImageOrientation
  createdAt: Date
  raw: ImageRaw
  url: ImageUrl
}
