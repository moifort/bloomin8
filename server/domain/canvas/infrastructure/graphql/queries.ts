import { CanvasQuery } from '~/domain/canvas/query'
import { builder } from '~/domain/shared/graphql/builder'
import { BatteryInfoType } from './types'

builder.queryField('canvasBattery', (t) =>
  t.field({
    type: BatteryInfoType,
    nullable: true,
    description: 'Latest battery report — null when no battery data has been recorded yet',
    resolve: () => CanvasQuery.getBattery(),
  }),
)
