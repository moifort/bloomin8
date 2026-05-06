import { ApolloServer } from '@apollo/server'
import type { GraphQLContext } from '~/domain/shared/graphql/builder'
import { schema } from '~/domain/shared/graphql/schema'
import { setApollo } from '~/utils/apollo'

export default defineNitroPlugin(async () => {
  const apollo = new ApolloServer<GraphQLContext>({ schema, introspection: true })
  await apollo.start()
  setApollo(apollo)
})
