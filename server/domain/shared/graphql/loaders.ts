// No DataLoader is required yet — bloomin8 has no per-request batched
// relations. Keep the factory in place so resolvers can plug into it later
// without restructuring the GraphQL context.
export const createLoaders = () => ({})

export type Loaders = ReturnType<typeof createLoaders>
