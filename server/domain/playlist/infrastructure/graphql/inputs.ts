import { builder } from '~/domain/shared/graphql/builder'

export const QuietHoursInput = builder.inputType('QuietHoursInput', {
  description:
    'Optional window during which the device should not pull. Currently start=23 / end=07 are hard-coded server-side; only enabled and timezone are honored.',
  fields: (t) => ({
    enabled: t.boolean({ required: true, description: 'Whether the quiet window applies' }),
    timezone: t.field({
      type: 'Timezone',
      required: true,
      description: 'IANA timezone used to evaluate the quiet window (e.g. Europe/Paris)',
    }),
  }),
})

export const StartPlaylistInput = builder.inputType('StartPlaylistInput', {
  description: 'Parameters required to (re)start the playlist and wake the device',
  fields: (t) => ({
    canvasUrl: t.field({
      type: 'CanvasUrl',
      required: true,
      description: 'Absolute URL of the BLOOMIN8 device on the local network',
    }),
    cronIntervalInHours: t.field({
      type: 'Hour',
      required: true,
      description: 'Interval between two image displays, in hours (1–168)',
    }),
    quietHours: t.field({
      type: QuietHoursInput,
      required: false,
      description: 'Optional quiet-hours configuration',
    }),
  }),
})
