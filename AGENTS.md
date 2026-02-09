# AGENTS.md - Codex guidance

## Scope
- Stack: Nitro + strict TypeScript.
- Match the coding style used in:
  - `server/routes/upload.post.ts`
  - `server/images`

## Core principles
- Keep code explicit, predictable, and maintainable.
- Prefer functions over classes.
- Avoid unnecessary abstractions.
- Keep the main function readable; do not split into many tiny helpers unless readability or reuse improves clearly.

## TypeScript rules
- `strict: true` is required.
- Never use `any`.
- Prefer `unknown` with narrowing, literal unions, and discriminated unions.
- Avoid explicit return types unless:
  1. the function is a public API contract,
  2. inference is ambiguous,
  3. the annotation protects an important domain union.
- Keep domain types in feature-local type files (`server/<feature>/types.ts`).

## Architecture
- Enforce route/domain separation.
- Route layer handles HTTP concerns only:
  1. parse inputs (query, params, body),
  2. minimal validation,
  3. map domain outcomes to HTTP,
  4. set headers and serialize responses.
- Domain layer handles business logic and storage access.
- Routes must not call `useStorage` directly.

## Feature template (apply this to every new feature)
- `server/<feature>/types.ts`
- `server/<feature>/index.ts`
- `server/routes/<feature>.<method>.ts`
- `server/routes/<feature>/[id].<method>.ts` (when needed)

Flow:
1. Route reads and normalizes input.
2. Route calls a domain function.
3. Domain returns typed outcomes (not implicit magic).
4. Route converts outcomes into HTTP responses.

## Route conventions
- Use Nitro naming: `<name>.<method>.ts` and dynamic segments `[param]`.
- Always use `export default eventHandler(async (event) => { ... })`.
- Use guard clauses and early returns/throws.
- JSON response contract: `{ status: number, data: ... }`.
- For binary responses, set `content-type` explicitly and return a `Buffer`.

## Error handling
- Use `createError({ statusCode, statusMessage })` for HTTP errors.
- Keep `statusMessage` short and clear.
- Avoid broad `try/catch`; catch only when remapping a technical failure to a useful contract.
- Let unexpected failures surface as `500` unless there is a clear domain-specific mapping.

## Domain conventions (images reference)
- Expose clear domain entry points (for example `saveImage`, `getImage`).
- Use a dedicated storage namespace (for example `useStorage('images')`).
- Type storage IO explicitly (`setItem<Image>`, `getItem<Image>`).
- Use `crypto.randomUUID()` for IDs.
- Return explicit typed outcomes for expected states (for example `Image | 'not-found'`) instead of throwing for normal control flow.
- Throw only for unexpected errors, throw error will be handled by Nitro.
- Keep HTTP knowledge out of domain code.
