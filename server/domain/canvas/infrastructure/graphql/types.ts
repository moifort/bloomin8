import type { Battery } from '~/domain/canvas/types'
import { builder } from '~/domain/shared/graphql/builder'

export const BatteryInfoType = builder.objectRef<Battery>('BatteryInfo').implement({
  description: 'Latest battery report received from the BLOOMIN8 device',
  fields: (t) => ({
    percentage: t.expose('percentage', {
      type: 'Percentage',
      description: 'Battery level as integer in [0, 100]',
    }),
    lastFullChargeDate: t.expose('lastFullChargeDate', {
      type: 'DateTime',
      nullable: true,
      description: 'When the device last reached 100% — null if never seen fully charged',
    }),
    lastPullDate: t.expose('lastPullDate', {
      type: 'DateTime',
      nullable: true,
      description: 'Timestamp of the most recent pull from the device',
    }),
  }),
})
