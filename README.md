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

## Deploy on CasaOS

### 1) Copy project on your CasaOS host

Clone this repository on the machine running CasaOS.

### 2) Install with Docker Compose

CasaOS supports importing `docker-compose.yml`:

1. Open CasaOS dashboard.
2. Go to **App Store** -> **Custom Install** -> **Import from docker-compose.yml**.
3. Paste the content of `docker-compose.yml` from this repo.
4. Install.

The app listens on port `3000` and stores persistent files in `./data` mapped to `/data` in the container.

### 3) Verify

- `GET http://<your-casaos-ip>:3000/settings`
- `GET http://<your-casaos-ip>:3000/eink_pull`

### 4) Optional: map data elsewhere

If you want host data outside the project folder, change this line in `docker-compose.yml`:

```yaml
volumes:
  - ./data:/data
```

to something like:

```yaml
volumes:
  - /DATA/AppData/canvas/data:/data
```
