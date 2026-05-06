import { builder } from '~/domain/shared/graphql/builder'

builder.queryField('health', (t) =>
  t.string({
    description: 'Liveness probe — always returns "ok" when the GraphQL server is up.',
    resolve: () => 'ok',
  }),
)
