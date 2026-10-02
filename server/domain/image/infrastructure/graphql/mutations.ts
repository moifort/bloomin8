import { GraphQLError } from 'graphql'
import { ImageCommand } from '~/domain/image/command'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationField('deleteAllImages', (t) =>
  t.field({
    type: 'Int',
    description: 'Delete every uploaded image. Returns the count of deleted entries.',
    resolve: () => ImageCommand.deleteAll(),
  }),
)

builder.mutationField('keepOnlyImages', (t) =>
  t.field({
    type: 'Int',
    description:
      'Delete every image except the given ones — final step of an album replacement, once the new album is uploaded. Refused with NO_KEPT_IMAGE when none of the ids exists, so a failed upload can never wipe the album. Returns the count of deleted images.',
    args: {
      ids: t.arg({
        type: ['ImageId'],
        required: true,
        description: 'Ids of the images to keep, as returned by POST /upload',
      }),
    },
    resolve: async (_root, { ids }) => {
      const result = await ImageCommand.keepOnly(ids)
      if (result === 'no-kept-image') {
        throw new GraphQLError('None of the images to keep exists', {
          extensions: { code: 'NO_KEPT_IMAGE' },
        })
      }
      return result
    },
  }),
)

builder.mutationField('deleteImages', (t) =>
  t.field({
    type: 'Int',
    description:
      'Delete the given images — used to roll back a cancelled upload. Unknown ids are ignored. Returns the count of deleted images.',
    args: {
      ids: t.arg({ type: ['ImageId'], required: true, description: 'Ids of the images to delete' }),
    },
    resolve: (_root, { ids }) => ImageCommand.deleteMany(ids),
  }),
)
