import * as canvasRepository from '~/domain/canvas/infrastructure/repository'

export namespace CanvasQuery {
  export const getBattery = () => canvasRepository.findBattery()
}
