import type { Brand } from 'ts-brand'

export type Percentage = Brand<number, 'Percentage'>
export type CanvasDate = Brand<string, 'CanvasDate'>

export type Battery = {
  percentage: Percentage
  lastFullChargeDate: Date | null
}
