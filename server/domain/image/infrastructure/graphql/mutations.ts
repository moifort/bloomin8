import { ImageCommand } from '~/domain/image/command'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationField('deleteAllImages', (t) =>
  t.field({
    type: 'Int',
    description: 'Delete every uploaded image. Returns the count of deleted entries.',
    resolve: () => ImageCommand.deleteAll(),
  }),
)
