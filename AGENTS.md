# AGENTS.md - Codex guidance

## Scope
- Stack: Nitro + strict TypeScript.
- Match the coding style used in:
  - `server/routes/upload.post.ts`
  - `server/images/types.ts`
  - `server/images/primitives.ts`
  - `server/images/index.ts`

## Core principles
- Keep code explicit, predictable, and maintainable.
- Prefer functions over classes.
- Avoid unnecessary abstractions.
- Keep the main function readable; do not split into tiny helpers unless readability or reuse clearly improves.

## TypeScript rules
- `strict: true` is required.
- Never use `any`.
- Prefer `unknown` with explicit narrowing.
- Use `ts-brand` for domain primitives (IDs and opaque strings).
- Avoid explicit return types unless:
  1. the function is a public API contract,
  2. inference is ambiguous,
  3. the annotation protects a domain union.

Example:
```ts
import type { Brand } from 'ts-brand'

export type ImageId = Brand<string, 'ImageId'>
export type ImageRaw = Brand<string, 'ImageRaw'>
export type ImageUrl = Brand<string, 'ImageUrl'>

export type Image = {
  id: ImageId
  orientation: 'P' | 'L'
  addedAt: Date
  raw: ImageRaw
  url: ImageUrl
}
```

## Architecture
- Enforce route/domain separation.
- Route layer handles HTTP only:
  1. parse input (query, params, body),
  2. validate/normalize input,
  3. map domain outcomes to HTTP responses.
- Domain layer handles business logic and storage.
- Routes must not call `useStorage` directly.

## Feature template (apply to every new feature)
- `server/<feature>/types.ts` for brand and entity types.
- `server/<feature>/primitives.ts` for primitive constructors/factories.
- `server/<feature>/index.ts` for domain use cases.
- `server/routes/<feature>.<method>.ts` and `server/routes/<feature>/[id].<method>.ts`.

Flow:
1. Route reads input.
2. Route converts external strings to branded primitives.
3. Route calls a domain function.
4. Domain returns typed results.
5. Route maps results/errors to HTTP.

## Branded primitives (`primitives.ts`)
- Build primitives with `make` from `ts-brand`.
- Validate input inside primitive constructors.
- Throw on invalid primitive input; route must map that to `400`.
- Keep constructors deterministic and side-effect free.
- Keep random ID generation in primitives (for example `randomImageId`).

Example:
```ts
import { make } from 'ts-brand'
import type { ImageId as ImageIdType, ImageUrl as ImageUrlType } from '~/images/types'

export const randomImageId = () => ImageId(crypto.randomUUID())

export const ImageId = (value?: string) => {
  if (!value) throw new Error(`ImageId must be a uuid, received: ${value}`)
  if (value.length !== 36) throw new Error(`ImageId must be 36 characters long, received: ${value}`)
  return make<ImageIdType>()(value)
}

export const ImageUrl = (value?: string) => {
  if (!value) throw new Error(`ImageUrl must be a string, received: ${value}`)
  return make<ImageUrlType>()(value)
}
```

## Route conventions
- Use Nitro naming: `<name>.<method>.ts` and dynamic segments `[param]`.
- Always use `export default eventHandler(async (event) => { ... })`.
- Use guard clauses and early returns/throws.
- JSON response contract: `{ status: number, data: ... }`.
- For binary responses, set `content-type` explicitly and return a `Buffer`.
- Convert route inputs to primitives before calling domain functions.

## Error handling
- Use `createError({ statusCode, statusMessage })` for HTTP errors.
- Map expected cases explicitly:
  - invalid input/primitive -> `400`
  - resource not found -> `404`
- Keep `statusMessage` short and clear.
- Avoid broad `try/catch`; catch only for intentional remapping.
- Let unexpected failures surface as `500`.

## Domain conventions (images reference)
- Domain APIs accept and return branded primitives (for example `ImageId`, `ImageRaw`, `ImageUrl`).
- Use a dedicated storage namespace (for example `useStorage('images')`).
- Type storage IO explicitly (`setItem<Image>`, `getItem<Image>`).
- Return explicit typed outcomes for expected states (`Image | 'not-found'`).
- Keep HTTP concerns out of domain code.

Example:
```ts
export const getImage = async (id: ImageId) => {
  const storage = useStorage('images')
  const image = await storage.getItem<Image>(id)
  if (!image) return 'not-found' as const
  return image
}
```
