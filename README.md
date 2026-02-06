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
- `POST /upload?orientation=P` — raw JPEG body.
- `GET /images/:filename` — serve stored JPEG.
- `GET /settings`
- `PUT /settings`

## Notes

- Upload filenames are generated server-side with a random name.
- Use `orientation=P` or `orientation=L` on upload.
- JPEG only.
