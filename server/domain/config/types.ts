import type { Brand } from 'ts-brand'

export type CanvasUrl = Brand<string, 'CanvasUrl'>
export type ServerUrl = Brand<string, 'ServerUrl'>

export type Config = {
  serverUrl: ServerUrl
}
