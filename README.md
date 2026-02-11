# Canvas Server

Nitro + TypeScript service that manages an image playlist for a BLOOMIN8 Canvas device.

The server:
- Stores uploaded images.
- Starts a playlist tied to a target canvas URL.
- Responds to the device pull loop through `/eink_pull`.
- Accepts display feedback through `/eink_signal`.

## Stack

- Nitro (H3)
- TypeScript (`strict: true`)
- Bun
- Nitro storage (filesystem drivers)
- `ts-brand` and `ts-pattern`

## Local Development

1. Install dependencies:

```bash
bun install
```

2. Start the dev server:

```bash
bun run dev
```

3. Server listens on `http://0.0.0.0:3000` by default.

## Build and Preview

```bash
bun run build
bun run preview
```

## Runtime Configuration

Runtime config is declared in `nitro.config.ts` and read in `/Users/thibaut/Code/canvas/server/config/index.ts`.

| Key | Env var | Default | Purpose |
| --- | --- | --- | --- |
| `runtimeConfig.serverUrl` | `NITRO_SERVER_URL` | `http://192.168.0.164:3000` | Public base URL used in responses to the canvas device |

## Storage

Nitro storage buckets are configured in `/Users/thibaut/Code/canvas/nitro.config.ts`:

- `images` -> `./data/images`
- `playlist` -> `./data/playlist`

Playlist state is persisted, including:
- Playlist status (`in-progress` or `stop`)
- Remaining image IDs for random non-repeating selection
- Pull interval in hours

## API

### `POST /upload`

Upload raw image bytes.

- Query:
  - `orientation`: orientation marker validated by the server (examples in `api.http` use `P`)
- Body:
  - `application/octet-stream`
- Success response:
  - `200` with `{ status, data: { id, url } }`

### `DELETE /images`

Delete all stored images.

- Success response:
  - `200` with `{ status, message }`

### `POST /playlist/start`

Start playlist processing and wake the device by configuring its upstream settings.

- JSON body:
  - `canvasUrl`: device base URL
  - `cronIntervalInHours`: pull interval
- Success response:
  - `200` with `{ status, message }`
- Failure response:
  - `400` when no images are available (`Playlist must have at least one image`)

### `GET /eink_pull`

Main endpoint called by the device on each wake cycle.

Behavior:
- Returns `SHOW` payload with `image_url` and next schedule when an image is available.
- Returns stop payload (`next_cron_time: null`) when playlist is missing/stopped/empty.
- Returns no-image payload for image lookup misses.

### `GET /eink_signal`

Feedback endpoint for device acknowledgements.

- Success response:
  - `200` with `{ status, message: "Feedback recorded" }`

## Typical Flow

1. Upload one or more images through `POST /upload`.
2. Start playlist using `POST /playlist/start`.
3. Device calls `GET /eink_pull` at scheduled times.
4. Server returns next image URL and next UTC pull time.
5. Device optionally calls `GET /eink_signal` after display.

## Useful Files

- `/Users/thibaut/Code/canvas/api.http`: ready-to-run local HTTP scenarios.
- `/Users/thibaut/Code/canvas/blomin8.md`: protocol notes for `/upstream/pull_settings`, `/eink_pull`, and `/eink_signal`.

## Docker

Build and run with compose:

```bash
docker compose up --build
```

The current compose file sets `NITRO_SERVER_URL` and exposes port `3000`.
