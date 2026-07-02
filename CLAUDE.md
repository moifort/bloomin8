# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Canvas is a full-stack image playlist manager for BLOOMIN8 Canvas e-ink display devices. The system consists of:
- **Backend**: Nitro/TypeScript server exposing GraphQL (Apollo Server + Pothos) plus a thin REST surface for the device protocol and binary uploads
- **iOS App**: SwiftUI app for uploading photos, controlling playlists, and watching device status (Apollo iOS)
- **iOS Widget**: Lock screen widget displaying device battery status (Apollo iOS in the extension)

## Backend Development

### Stack
- Nitro (H3 web framework) + Bun runtime
- TypeScript 5.5 with `strict: true`
- Apollo Server 5.5 + Pothos 4.12 (code-first GraphQL)
- DataLoader 2.2 (per-request batched relations — wired but currently empty)
- Nitro storage (filesystem drivers)
- Type safety: `ts-brand` (branded types), `ts-pattern` (pattern matching)
- Validation: Zod schemas
- Linting/Formatting: Biome 2.3.14

### Common Commands

```bash
bun install                      # Install dependencies
bun run dev                      # Start dev server (http://0.0.0.0:3000)
bun run build                    # Build for production
bun run preview                  # Preview production build
bun run generate:graphql         # Re-export shared/schema.graphql from Pothos
bun test                         # Unit tests on primitives + business rules
bunx biome check                 # Lint + format check
docker compose up --build        # Run in Docker
```

After regenerating the GraphQL schema, regenerate Apollo iOS types:

```bash
cd ios && /tmp/apollo-ios-cli generate
```

### Architecture (DDD layout)

```
server/
├── domain/
│   ├── shared/
│   │   ├── types.ts | primitives.ts          # Hour
│   │   └── graphql/
│   │       ├── builder.ts                    # Pothos SchemaBuilder, Context, Scalars
│   │       ├── scalars.ts                    # Custom scalars per branded type
│   │       ├── loaders.ts                    # createLoaders() — empty for now
│   │       └── schema.ts                     # Side-effect imports + builder.toSchema()
│   ├── playlist/
│   │   ├── types.ts | primitives.ts          # PlaylistId, PlaylistStatus, Timezone, …
│   │   ├── business-rules.ts                 # applyQuietHours, pickRandomImageId (pure)
│   │   ├── query.ts | command.ts             # Public read/write namespaces
│   │   ├── read-model.ts                     # buildPlaylistProgress (cross-domain)
│   │   └── infrastructure/
│   │       ├── repository.ts                 # PRIVATE — useStorage('playlist')
│   │       └── graphql/                      # enums, types, inputs, queries, mutations
│   ├── image/                                # Same DDD layout, command-only GraphQL
│   ├── canvas/                               # Same DDD layout, query-only GraphQL
│   ├── config/                               # Server runtime config (CanvasUrl, ServerUrl)
│   └── system/infrastructure/graphql/        # health query
├── routes/
│   ├── graphql.ts                            # Apollo GET/POST handler
│   ├── eink_pull.get.ts                      # Device protocol, REST forced
│   ├── eink_signal.get.ts                    # Device feedback, REST forced
│   ├── upload.post.ts                        # Raw JPEG upload, REST forced
│   ├── images/[name].get.ts                  # Binary file serving, REST forced
│   └── health.get.ts                         # Docker healthcheck
├── middleware/canvas-battery.ts              # Captures ?battery=X from /eink_pull
├── plugins/
│   ├── 00-startup.ts | 01-logger.ts          # Bootstrap + logging
│   └── 02-graphql.ts                         # ApolloServer instantiation + setApollo()
├── utils/apollo.ts                           # useApollo() singleton
└── system/logger.ts                          # createLogger(tag) wrapper
```

**DDD rules:**
- `repository.ts` is private to its domain; cross-domain reads go through public `XxxQuery` namespaces or via `read-model.ts` files (read-models can import sibling domain repositories — explicit cross-domain composition).
- `business-rules.ts` is pure (no IO, no async) and 100% unit-tested.
- Validation lives at the domain boundary via Zod constructors in `primitives.ts`. Once a value passes the constructor, downstream code trusts it.
- Errors: domain commands return discriminated unions (`'playlist-empty'`, `'not-paused'`, …); GraphQL resolvers map them to `GraphQLError` with `extensions.code`. No GraphQL union types.

### GraphQL Layer

- **Endpoint**: `POST /graphql` for operations, `GET /graphql` for Apollo Sandbox in dev.
- **Schema**: code-first with Pothos. `defaultFieldNullability: false` — every field is `!` unless explicitly marked `nullable: true`.
- **Custom scalars**: every branded type has a Pothos scalar (Hour, Percentage, PlaylistId, Timezone, ImageId, ImageUrl, CanvasUrl, ServerUrl, CanvasDate) wired to its Zod constructor via `validatedParse`. Errors surface as `GraphQLError(BAD_USER_INPUT)`.
- **SDL export**: committed to `shared/schema.graphql`. Regenerate via `bun run generate:graphql`. Excluded from biome formatting (Pothos owns its canonical formatting).
- **Tree-shaking**: `nitro.config.ts` whitelists `/graphql/` paths in `rollupConfig.treeshake.moduleSideEffects` — without it Rollup elides the side-effect imports of query/mutation files, leaving Apollo with an empty schema.

### Storage Buckets (unchanged)

- `images`: `./data/images` — `<id>_P.jpg` / `<id>_L.jpg`
- `playlist`: `./data/playlist` — playlist state (single hardcoded `DEFAULT_PLAYLIST_ID`)
- `canvas`: `./data/canvas` — last battery report (`battery` key)

### Configuration

`nitro.config.ts` runtime config:
- `NITRO_SERVER_URL`: Public URL the device should call back (default: `http://192.168.0.164:3000`)

### BLOOMIN8 Device Protocol (REST, unchanged)

1. Server wakes the device with `PUT {deviceUrl}/upstream/pull_settings` carrying `cron_time` + `upstream_url` (called by `CanvasCommand.wakeUp`).
2. Device pulls `GET {serverUrl}/eink_pull?device_id&pull_id&cron_time&battery`.
3. Server responds with `image_url` and `next_cron_time` (ISO 8601 UTC, no milliseconds).
4. Device displays the JPEG (rotated 90° CCW for `_L.jpg`) and may call `GET {serverUrl}/eink_signal?pull_id&success`.
5. Device sleeps until `next_cron_time`.

The `canvas-battery` middleware captures `?battery=X` on `/eink_pull` and persists it to the `canvas` bucket.

### Data Flow

1. iOS app uploads photos → REST `POST /upload` → stored in `./data/images`.
2. iOS app starts playlist → GraphQL `mutation startPlaylist` → wakes device.
3. Device periodically pulls REST `GET /eink_pull` → server picks the next image, returns URL + schedule.
4. Device's `?battery=X` query param is captured by middleware → persisted in `canvas` bucket.
5. iOS app + widget poll GraphQL `query canvasBattery` and `query playlistProgress` for status.

## iOS Development

### Stack
- Swift with SwiftUI, iOS 26+
- MVVM with `@Observable`
- UserDefaults + App Groups for app↔widget sharing (`group.polyforms.canvas`)
- Apollo iOS 1.18.0 (SPM)

### Project Structure

```
ios/
├── apollo-codegen-config.json                # Apollo iOS codegen, swift-package-manager mode
└── Canvas/
    ├── Canvas.xcodeproj
    ├── Canvas/
    │   ├── Features/
    │   │   ├── Playlist/GraphQL/             # 5 .graphql operations
    │   │   ├── Images/GraphQL/               # DeleteAllImages
    │   │   └── Canvas/GraphQL/               # CanvasBattery
    │   ├── Shared/GraphQLClient.swift        # ApolloClient factory + async bridges
    │   ├── PlaylistService.swift             # Wraps StartPlaylist/Pause/Resume/Progress mutations
    │   ├── ImageService.swift                # Wraps DeleteAllImages
    │   ├── CanvasStatusService.swift         # Wraps CanvasBattery query
    │   ├── UploadService.swift               # REST POST /upload (raw JPEG)
    │   └── AppViewModel.swift                # Orchestrates services
    ├── CanvasBatteryWidget/
    │   ├── GraphQL/CanvasBatteryWidget.graphql
    │   └── CanvasBatteryWidget.swift         # TimelineProvider via Apollo
    └── CanvasGraphQL/                        # Local SPM package emitted by apollo-ios-cli
        ├── Package.swift
        └── Sources/                          # Generated types — both targets import this
```

### Key Components

- **AppViewModel.swift**: single source of truth, manages upload queue (max 5 concurrent), drives the GraphQL services. Keeps original public API; only the underlying transport changed.
- **GraphQLClient.swift**: `client(for: URL)` factory; `fetchAsync` / `performAsync` extensions bridge Apollo's callback API to async/await. No auth interceptor — bloomin8 runs on a trusted local network.
- **Widget**: timeline provider hits `/graphql` directly via a private inlined `WidgetGraphQLClient` (the widget extension can't import sibling Canvas-target files but does share `CanvasGraphQL` SPM package).
- **Custom scalars** are typealiased to `String` by default. Numeric scalars (Hour, Percentage) are converted at the service boundary via `Int(scalar)`.

### Codegen Workflow

1. Edit `.graphql` operations under `Canvas/Canvas/Features/**/GraphQL/` or `Canvas/CanvasBatteryWidget/GraphQL/`.
2. Run `cd ios && /tmp/apollo-ios-cli generate` (binary downloaded from apollo-ios releases 1.18.0).
3. Commit the regenerated `Canvas/CanvasGraphQL/Sources/` to keep the build reproducible.
4. After backend schema changes: run `bun run generate:graphql` first, commit `shared/schema.graphql`, then run iOS codegen.

## Testing

### Backend
- `bun test`: unit tests on `*.unit.test.ts` files (primitives + business-rules). 42 tests at the time of this writing.
- `api.http`: ready-to-run REST + GraphQL request samples.
- `bun run dev` + `curl` for end-to-end smoke testing.

### iOS
Build and run in Xcode (or `xcodebuild` from CLI). Widget testing:
1. Run the app on device/simulator
2. Long-press home screen → add widget → select "Canvas Battery"
3. Widget refreshes every 15 minutes automatically (and on app launch)

## Important Notes

- **Image Orientation**: stored portrait, filename suffix (`_P` / `_L`) drives device rotation.
- **Time Format**: device protocol uses ISO 8601 UTC without milliseconds (`2025-11-01T08:30:00Z`). `CanvasDate` primitive enforces this.
- **Battery Tracking**: middleware `server/middleware/canvas-battery.ts` captures `?battery=X` on every request, hot-applied for `/eink_pull`.
- **Type Safety**: never bypass branded types or `match().exhaustive()` — they prevent runtime errors.
- **Concurrency**: iOS app limits concurrent uploads to 5 to prevent memory issues with large photos.
- **DEFAULT_PLAYLIST_ID**: bloomin8 is mono-playlist by design; the canonical id is exported from `server/domain/playlist/primitives.ts`.
