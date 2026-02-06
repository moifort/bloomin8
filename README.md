# BLOOMIN8 Pull Server (Nitro)

Minimal upstream server compatible with `docs/Schedule_Pull_API.md`.

## Quick start

```bash
npm install
npm run dev
```

Or with Bun:

```bash
bun install
bun run dev
```

By default, data is stored in `./data`. For production, set:

```bash
DATA_DIR=/var/lib/bloomin8
```

## Endpoints

- `GET /eink_pull` — called by the device.
- `POST /upload?filename=photo_P.jpg` — raw JPEG body.
- `GET /images/:filename` — serve stored JPEG.
- `GET /settings`
- `PUT /settings`

## Notes

- Filenames must end with `_P.jpg` or `_L.jpg`.
- JPEG only.
