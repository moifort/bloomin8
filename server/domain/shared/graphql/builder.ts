import SchemaBuilder from '@pothos/core'
import { GraphQLScalarType } from 'graphql'
import type { H3Event } from 'h3'
import type { CanvasDate, Percentage } from '~/domain/canvas/types'
import type { CanvasUrl, ServerUrl } from '~/domain/config/types'
import type { ImageId, ImageUrl } from '~/domain/image/types'
import type { PlaylistId, Timezone } from '~/domain/playlist/types'
import type { Hour } from '~/domain/shared/types'
import type { Loaders } from './loaders'

export type GraphQLContext = {
  event: H3Event
  loaders: Loaders
}

const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'ISO 8601 date-time string',
  serialize: (value: unknown) => (value instanceof Date ? value.toISOString() : value),
  parseValue: (value: unknown) => new Date(value as string),
})

export const builder = new SchemaBuilder<{
  Context: GraphQLContext
  DefaultFieldNullability: false
  Scalars: {
    DateTime: { Input: Date; Output: Date }
    Hour: { Input: Hour; Output: Hour }
    Percentage: { Input: Percentage; Output: Percentage }
    PlaylistId: { Input: PlaylistId; Output: PlaylistId }
    Timezone: { Input: Timezone; Output: Timezone }
    ImageId: { Input: ImageId; Output: ImageId }
    ImageUrl: { Input: ImageUrl; Output: ImageUrl }
    CanvasUrl: { Input: CanvasUrl; Output: CanvasUrl }
    ServerUrl: { Input: ServerUrl; Output: ServerUrl }
    CanvasDate: { Input: CanvasDate; Output: CanvasDate }
  }
}>({ defaultFieldNullability: false })

builder.addScalarType('DateTime', DateTimeScalar)
builder.queryType({})
builder.mutationType({})
