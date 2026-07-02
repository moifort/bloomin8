import { builder } from '~/domain/shared/graphql/builder'

export const QuietHoursInput = builder.inputType('QuietHoursInput', {
  description: 'Window during which the device should not pull new images',
  fields: (t) => ({
    enabled: t.boolean({ required: true, description: 'Whether the quiet window applies' }),
    timezone: t.field({
      type: 'Timezone',
      required: true,
      description: 'IANA timezone used to evaluate the quiet window (e.g. Europe/Paris)',
    }),
    start: t.int({
      required: false,
      description: 'Hour at which the quiet window starts, in [0, 23]. Defaults to 23.',
    }),
    end: t.int({
      required: false,
      description: 'Hour at which the quiet window ends, in [0, 23]. Defaults to 7.',
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
