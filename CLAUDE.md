# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Canvas is a full-stack image playlist manager for BLOOMIN8 Canvas e-ink display devices. The system consists of:
- **Backend**: Nitro/TypeScript server managing image storage and playlists
- **iOS App**: SwiftUI app for uploading photos
- **iOS Widget**: Lock screen widget displaying device battery status

## Backend Development

### Stack
- Nitro (H3 web framework)
- TypeScript 5.5 with `strict: true`
- Bun runtime
- Nitro storage (filesystem drivers)
- Type safety: `ts-brand` (branded types), `ts-pattern` (pattern matching)
- Validation: Zod schemas
- Linting/Formatting: Biome 2.3.14

### Common Commands

```bash
bun install                # Install dependencies
bun run dev                # Start dev server (http://0.0.0.0:3000)
bun run build              # Build for production
bun run preview            # Preview production build
docker compose up --build  # Run in Docker
```

### Architecture Patterns

**Namespace Pattern**: Business logic organized as TypeScript namespaces (not classes)
- `Playlist.start()`, `Playlist.stop()`, `Images.upload()`, etc.
- Located in `/server/[domain]/` directories
- Import with `import { Playlist } from "~/server/playlist"`

**Branded Types**: Type-safe primitive wrappers prevent ID confusion
- `ImageId`, `PlaylistId`, `PullId` from `ts-brand`
- Never mix different ID types - compiler enforces this

**Storage Buckets**:
- `images`: `/data/images` - Uploaded images with orientation suffix (`_P.jpg`, `_L.jpg`)
- `playlist`: `/data/playlist` - Playlist state (status, remaining images, interval)
- `canvas`: `/data/canvas` - Latest battery percentage from device

### Configuration

Runtime config in `nitro.config.ts`:
- `NITRO_SERVER_URL`: Public URL for device callbacks (default: `http://192.168.0.164:3000`)
- `HOST`: Server bind address (default: `0.0.0.0`)
- `PORT`: Server port (default: `3000`)

### Critical Files

- `/server/routes/` - API endpoints (upload, playlist, eink_pull, etc.)
- `/server/config/index.ts` - Runtime configuration
- `/server/[domain]/` - Business logic modules (canvas, images, playlist)
- `/api.http` - Ready-to-run HTTP request examples
- `/blomin8.md` - BLOOMIN8 device protocol documentation

### BLOOMIN8 Device Protocol

The Canvas e-ink device uses a scheduled pull loop:
1. Server configures device via `PUT {deviceUrl}/upstream/pull_settings` with `cron_time` and `upstream_url`
2. Device wakes at scheduled time, calls `GET {serverUrl}/eink_pull?battery=X`
3. Server responds with `image_url` and `next_cron_time` (ISO 8601 UTC)
4. Device displays image, optionally calls `GET {serverUrl}/eink_signal?success=1`
5. Device sleeps until next_cron_time

**Image Requirements**:
- Stored in portrait orientation (rotate landscape 90° clockwise before storage)
- Filename suffix indicates display orientation: `_P.jpg` (portrait) or `_L.jpg` (landscape)
- Device rotates `_L.jpg` images 90° counter-clockwise on display

**Key Endpoints**:
- `POST /upload?orientation=P|L` - Upload image bytes
- `POST /playlist/start` - Initialize playlist and wake device
- `GET /eink_pull?battery=X` - Device pulls next image (returns `next_cron_time` + `image_url`)
- `GET /canvas/battery` - Get latest battery report
- `GET /eink_signal?pull_id=X&success=1` - Device feedback

### Data Flow

1. iOS app uploads photos → `POST /upload` → stored in `/data/images`
2. User starts playlist → `POST /playlist/start` → wakes Canvas device
3. Device periodically calls `GET /eink_pull` → server returns next image URL + schedule
4. Device reports battery in pull request → stored in `/data/canvas/battery-percentage`
5. iOS widget reads battery via `GET /canvas/battery`

## iOS Development

### Stack
- Swift with SwiftUI
- MVVM architecture with `@Observable` (Observation framework)
- UserDefaults with App Groups for data sharing
- Swift async/await with task groups

### Project Structure
- `/ios/Canvas/Canvas/` - Main iOS app source
- `/ios/Canvas/CanvasBatteryWidget/` - Lock screen widget
- App Group ID: `group.polyforms.canvas` (shared data between app and widget)

### Key Components

**AppViewModel.swift** (`/ios/Canvas/Canvas/AppViewModel.swift`):
- Single source of truth for app state
- Manages photo upload queue with concurrency limit (max 5 concurrent)
- Fetches battery percentage from server
- Persists server URL and battery data to UserDefaults

**CanvasBatteryWidget.swift** (`/ios/Canvas/CanvasBatteryWidget/CanvasBatteryWidget.swift`):
- TimelineProvider pattern with 15-minute refresh interval
- Displays battery percentage as color-coded ring (red/orange/green)
- Fake transparency using Home Screen screenshot as background
- Reads data from shared UserDefaults (`group.polyforms.canvas`)

**Shared Data Keys** (in `CanvasWidgetStore` enum):
- `canvas.server.url` - Server base URL
- `canvas.battery.percentage` - Cached battery percentage (Int)
- `canvas.widget.background.position` - Widget position on home screen
- `canvas-widget-background.png` - Home screen screenshot file

### Widget Refresh Flow
1. Widget timeline provider calls `resolveBatteryPercentage()` every 15 minutes
2. Fetches from `GET {serverUrl}/canvas/battery`
3. On success: caches percentage in UserDefaults
4. On failure: reads last cached value from UserDefaults
5. Creates `CanvasBatteryEntry` with battery data and timestamp
6. SwiftUI renders widget with color-coded ring

## Testing

### Backend
Use `/api.http` for manual API testing with VS Code REST Client or similar.

### iOS
Build and run in Xcode. Test widget by:
1. Running app on device/simulator
2. Long-press home screen → add widget → select "Canvas Battery"
3. Widget refreshes every 15 minutes automatically

## Important Notes

- **Image Orientation**: All images stored in portrait, filename suffix determines display orientation
- **Time Format**: Device protocol uses ISO 8601 UTC (`2025-11-01T08:30:00Z`)
- **Battery Tracking**: Middleware in `/server/middleware/01.persist-battery.ts` captures battery from query params
- **Type Safety**: Never bypass branded types or pattern matching - they prevent runtime errors
- **Concurrency**: iOS app limits concurrent uploads to prevent memory issues with large photos