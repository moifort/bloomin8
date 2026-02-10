import type { Brand } from 'ts-brand'

export type CanvasUrl = Brand<string, 'CanvasUrl'>
export type ServerUrl = Brand<string, 'ServerUrl'>
export type Hour = Brand<number, 'Hour'>

export type Config = {
  canvasUrl: CanvasUrl
  serverUrl: ServerUrl
  cronIntervalInHours: Hour
}
