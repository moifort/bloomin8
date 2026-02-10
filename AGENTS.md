# AGENTS.md - Nitro TypeScript Engineering Playbook

## 1) Goal and scope
This document defines how AI/code agents should design, implement, and review Nitro projects in the same style as this codebase.

Primary objective:
- Keep code simple, explicit, and predictable.
- Favor functional design (pure functions + explicit side effects).
- Keep domain logic independent from transport/runtime details.

Use this playbook for Nitro + H3 + Bun + strict TypeScript projects.

## 2) Baseline stack and non negotiables
- Runtime: Nitro (server app, filesystem storage via Nitro storage drivers).
- Language: TypeScript with `strict: true` and strong compiler guardrails.
- Tooling: Biome for formatting/linting, Bun for package/runtime.
- Typing approach: `ts-brand` for opaque primitives, `ts-pattern` for exhaustive branching where useful.

Non negotiables:
- No `any` in business code.
- No classes unless there is measurable value over functions.
- No hidden state and no implicit global mutation.
- Side effects are isolated and explicit.

## 3) Reference architecture

### 3.1 Layering
Use a simple 3 layer model:
1. HTTP/transport adapters (`server/routes/*`)
2. Domain/use-case modules (`server/<domain>/index.ts`)
3. Infrastructure adapters (Nitro storage, fetch to external systems, runtime config)

Rules:
- Routes parse/validate input and map output to HTTP shape.
- Domain orchestrates behavior and business decisions.
- Infrastructure performs I/O only.

### 3.2 Folder conventions (recommended)
```txt
server/
  config/
    types.ts
    primitives.ts
    index.ts
  <domain>/
    types.ts
    primitives.ts
    index.ts
  routes/
    <endpoint>.<method>.ts
    <resource>/[param].<method>.ts
  plugins/
    <plugin>.ts
```

### 3.3 Per domain file roles
- `types.ts`: domain contracts and branded types only.
- `primitives.ts`: constructors/validators for branded values.
- `index.ts`: use cases and composition of operations.

This split keeps type definitions stable and localizes runtime validation logic.

Trade off:
- More files and boilerplate.
- Better readability and safer refactors in exchange.

## 4) Type system and validation standards

### 4.1 Branded primitives
Use branded types for IDs, URLs, dates, and constrained values.

Why:
- Prevents accidental mixing of semantically different strings/numbers.
- Makes function signatures self documenting.

Trade off:
- Requires explicit constructors and conversion points.

### 4.2 Primitive constructors
Each branded type must have one constructor in `primitives.ts` that:
- Accepts `unknown` input.
- Validates shape/invariants.
- Returns branded value or fails fast.

Guidelines:
- Validation errors should clearly state expected vs received value.
- Keep constructors deterministic and side effect free.
- Avoid duplicate validation in routes and domain; call constructor once at boundary.

### 4.3 Result modeling
For expected business outcomes, do not throw exceptions.
Use explicit union outcomes.

Minimal style (as in this project):
- literal outcomes like `'not-found' | 'playlist-empty' | 'playlist-stopped'`

Preferred scalable style:
- discriminated unions:
```ts
type NextImageResult =
  | { tag: 'ok'; image: Image; nextAt: Date }
  | { tag: 'playlist-empty' }
  | { tag: 'playlist-stopped' }
  | { tag: 'image-not-found' }
```

Why:
- Prevents exception driven control flow.
- Makes all cases visible at call sites.

Trade off:
- Slightly more verbose than throwing errors.

### 4.4 Exhaustiveness
When branching on unions/status:
- Use `ts-pattern` + `.exhaustive()` or a `never` check in `switch`.
- No default branch that hides missing cases.

## 5) HTTP route design rules

Routes are adapters, not business layers.

A route should only:
1. Read params/body/query/headers.
2. Convert inputs through primitives.
3. Call a single use case or orchestrator.
4. Map domain result to HTTP response.

Do not:
- Keep domain state in routes.
- Query storage directly from routes (except tiny glue in rare cases).
- Duplicate domain decisions in handlers.

Error mapping:
- Invalid client input -> `createError({ statusCode: 400, ... })`
- Missing resource -> `404`
- Unexpected failures -> throw and let Nitro error handling/logging capture

## 6) Domain coding rules

### 6.1 Function first
- Prefer namespaces/modules with exported functions over classes.
- Keep functions small and intention revealing.
- Prefer early returns over nested branching.

### 6.2 Purity and side effects
- Keep pure transforms isolated from I/O calls.
- Group side effects so orchestration flow is obvious.

### 6.3 State updates
When persisting state:
- Read current state once.
- Compute next state explicitly.
- Write full next state (immutable update style).
- Avoid hidden in place mutation.

### 6.4 Naming
Use names that encode business intent, not implementation detail.
Examples:
- `start`, `nextImage`, `getById`, `getByName`, `save`

Avoid vague names:
- `processData`, `handleThing`, `doStuff`

### 6.5 Shadowing and ambiguity
- No variable shadowing inside branches.
- No reused names for different semantic values in the same function.

Why:
- Reduces logic bugs in branch heavy orchestration.

## 7) Config and runtime boundaries

- Centralize runtime config reading in one module (`server/config/index.ts`).
- Immediately convert runtime values to branded primitives.
- Pass config values explicitly to use cases; avoid hidden global reads deep in domain.

Nitro specifics:
- Use `runtimeConfig` in `nitro.config.ts` with env override support.
- Keep all default config values explicit and documented.

## 8) Storage and external I/O

### 8.1 Nitro storage
- Use named storage buckets (`useStorage('images')`, `useStorage('playlist')`).
- Keep key format stable and documented.
- Keep serialized shape typed with generics.

### 8.2 External HTTP calls
- Wrap remote protocol calls in dedicated module functions.
- Validate data sent to external systems (dates, URLs, required fields).
- Check `response.ok`; include response body in failure context when safe.

### 8.3 Binary payloads
For image/binary workflows:
- Keep transport format explicit (`base64` in storage, jpeg response content type).
- Keep orientation or format constraints as validated primitives.

## 9) Date/time policy

- Always use UTC ISO timestamps for external protocols.
- Normalize timestamps once (for example remove milliseconds if protocol requires).
- Keep scheduling math explicit (`hours * 60 * 60 * 1000`).
- Never mix locale times and UTC in the same flow without explicit conversion.

## 10) Logging and observability

- Provide request/response/error hooks via Nitro plugins.
- Log structured context (path, status, payload metadata) without leaking sensitive payloads.
- Startup plugin should log resolved config in safe form.

Trade off:
- More logs can increase noise; prefer concise structured logs over verbose dumps.

## 11) Simplicity guardrails

Before adding abstraction, verify all are true:
1. At least two real call sites need the abstraction.
2. It removes repeated business logic (not just repeated lines).
3. It lowers cognitive load for future maintainers.

If not true, keep direct code.

## 12) Testing strategy (required for production)

Priority tests:
1. Primitive constructors: accept valid values, reject invalid values.
2. Domain use cases: behavior and state transitions.
3. Route adapters: input/output contracts and status codes.
4. Infrastructure adapters: thin contract tests around storage/fetch wrappers.

Rules:
- Deterministic tests only.
- No reliance on wall clock randomness without controlled injection.
- Validate behavior, not private implementation.

Recommended seam points:
- Inject current time function for scheduling logic.
- Inject random selection function for predictable playlist tests.

## 13) Decision matrix (choice -> why -> cost)

- Branded types -> stronger API contracts -> extra constructor code.
- Route thinness -> better separation and easier tests -> more cross file navigation.
- Union results over exceptions -> explicit business flow -> more branch handling.
- Central config module -> single source of truth -> one additional indirection.
- Named storage buckets -> clear persistence boundaries -> bucket management discipline needed.
- Exhaustive matching -> compile time safety on new cases -> stricter coding style.

## 14) PR review checklist

Architecture:
- Domain logic is not leaking into routes.
- Side effects are isolated and obvious.

Types:
- New identifiers/URLs/dates are branded.
- No `any` added.
- Union branches are exhaustive.

Behavior:
- Error cases are explicit and mapped to correct HTTP responses.
- State transitions are immutable and easy to trace.

Maintainability:
- Names are precise.
- No unnecessary abstraction added.
- Comments explain why when needed, not what.

Testing:
- New behavior has deterministic tests.
- Regression paths and edge cases are covered.

## 15) Quick template for a new domain

1. Create `server/<domain>/types.ts`
- Define branded types and domain entity contracts.

2. Create `server/<domain>/primitives.ts`
- Add constructors/validators for each branded value.

3. Create `server/<domain>/index.ts`
- Implement use cases as small composable functions.
- Return explicit union outcomes for expected business cases.

4. Add route adapter(s) in `server/routes/*`
- Parse input -> call primitives -> call use case -> map result to HTTP.

5. Add storage bucket config if needed in `nitro.config.ts`

6. Add tests for primitives, use cases, and routes.

---

If a requested implementation conflicts with this playbook, state the conflict explicitly, explain long term maintenance impact, and propose the smallest viable alternative that preserves clarity and reliability.
