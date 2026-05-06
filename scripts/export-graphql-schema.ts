import { createStorage } from 'unstorage'
import memoryDriver from 'unstorage/drivers/memory'

// Pothos resolvers reference useStorage transitively via the domain modules.
// This script runs outside Nitro, so we install an in-memory shim before
// importing the schema graph.
;(globalThis as { useStorage?: unknown }).useStorage = () =>
  createStorage({ driver: memoryDriver() })

const { printSchema } = await import('graphql')
const { schema } = await import('../server/domain/shared/graphql/schema')

await Bun.write('shared/schema.graphql', printSchema(schema))

process.stdout.write('Exported GraphQL schema to shared/schema.graphql\n')
