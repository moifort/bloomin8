import { GraphQLError } from 'graphql'
import { ZodError } from 'zod'
import { CanvasDate, Percentage } from '~/domain/canvas/primitives'
import { CanvasUrl, ServerUrl } from '~/domain/config/primitives'
import { ImageId, ImageUrl } from '~/domain/image/primitives'
import { PlaylistId, Timezone } from '~/domain/playlist/primitives'
import { Hour } from '~/domain/shared/primitives'
import { builder } from './builder'

const validatedParse =
  <T>(name: string, parse: (value: unknown) => T) =>
  (value: unknown): T => {
    try {
      return parse(value)
    } catch (error) {
      const message =
        error instanceof ZodError
          ? error.issues.map(({ message }) => message).join(', ')
          : `Invalid ${name}`
      throw new GraphQLError(`Invalid value for ${name}: ${message}`, {
        extensions: { code: 'BAD_USER_INPUT' },
      })
    }
  }

builder.scalarType('Hour', {
  description: 'Cron interval in hours, integer in [1, 168]',
  serialize: (value) => value as number,
  parseValue: validatedParse('Hour', Hour),
})

builder.scalarType('Percentage', {
  description: 'Battery percentage, integer in [0, 100]',
  serialize: (value) => value as number,
  parseValue: validatedParse('Percentage', Percentage),
})

builder.scalarType('PlaylistId', {
  description: 'Playlist unique identifier (UUID v4)',
  serialize: (value) => value as string,
  parseValue: validatedParse('PlaylistId', PlaylistId),
})

builder.scalarType('Timezone', {
  description: 'IANA timezone identifier (e.g. Europe/Paris)',
  serialize: (value) => value as string,
  parseValue: validatedParse('Timezone', Timezone),
})

builder.scalarType('ImageId', {
  description: 'Image unique identifier (UUID v4)',
  serialize: (value) => value as string,
  parseValue: validatedParse('ImageId', ImageId),
})

builder.scalarType('ImageUrl', {
  description: 'Server-relative path to an image file (must start with /)',
  serialize: (value) => value as string,
  parseValue: validatedParse('ImageUrl', ImageUrl),
})

builder.scalarType('CanvasUrl', {
  description: 'Absolute URL of the BLOOMIN8 device',
  serialize: (value) => value as string,
  parseValue: validatedParse('CanvasUrl', CanvasUrl),
})

builder.scalarType('ServerUrl', {
  description: 'Absolute URL the device should call back to',
  serialize: (value) => value as string,
  parseValue: validatedParse('ServerUrl', ServerUrl),
})

builder.scalarType('CanvasDate', {
  description: 'ISO 8601 UTC date-time normalized without milliseconds',
  serialize: (value) => value as string,
  parseValue: validatedParse('CanvasDate', CanvasDate),
})
