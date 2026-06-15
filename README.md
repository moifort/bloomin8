# Canvas

A self-hosted alternative to the official BLOOMIN8 app for managing images on your Canvas e-ink display.

## Why?

The official BLOOMIN8 app has several limitations:

- Cannot upload iOS photo albums directly
- Crashes when uploading more than ~30 photos
- Uploads photos to an unknown third-party cloud
- No widget or quick way to monitor device status

Canvas solves all of these by running a lightweight server on your own network:

- **Bulk upload** — Send your entire photo library without crashes
- **Self-hosted** — Your photos stay on your server, never leave your network
- **iOS app** — Simple SwiftUI app to upload photos and manage playlists
- **Battery widget** — iOS lock screen widget showing battery level and days since last charge
- **Apple Home** — Appears in HomeKit: battery level plus a play/pause switch you can control with Siri

## How It Works

1. Upload photos from the iOS app to your Canvas server
2. Start a playlist — the server wakes the e-ink device
3. The device periodically pulls a new image from the server and displays it
4. The iOS widget shows the current battery level at a glance

## Installation

### Docker Compose

Create a `docker-compose.yml`:

```yaml
services:
  canvas-server:
    image: moifort/bloomin8:latest
    container_name: canvas-server
    restart: unless-stopped
    environment:
      HOST: 0.0.0.0
      PORT: "3000"
      NITRO_SERVER_URL: http://<YOUR_SERVER_IP>:3000
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
```

> Replace `<YOUR_SERVER_IP>` with the local IP address of the machine running the server (e.g. `192.168.0.165`). The BLOOMIN8 device uses this URL to pull images, so it must be reachable on your network.

Then start the server:

```bash
docker compose up -d
```

### CasaOS

A ready-to-use CasaOS configuration is available in `docker-compose.casaos.yml`. Import it directly from the CasaOS dashboard.

### iOS App

Build and install the iOS app from `ios/Canvas/` using Xcode. On first launch, set the server URL to point to your Canvas server (e.g. `http://192.168.0.165:3000`).

![iOS App](ios.PNG)

### iOS Widget

After installing the app, add the **Canvas Battery** widget to your lock screen or home screen. It refreshes every 15 minutes and displays the current battery percentage of your e-ink display.

![iOS Widget](ios-widget.PNG)

### Apple Home (HomeKit)

The server publishes a HomeKit accessory so your Canvas shows up in the **Home** app and responds to Siri:

- a **switch** that plays/pauses the playlist (e.g. _"Hey Siri, turn off Canvas"_)
- the current **battery level**, with a low-battery warning

To pair it:

1. Make sure the server is running and reachable on your local network.
2. In the **Home** app, tap **+** → **Add Accessory** → **More options…** and select **Canvas**.
3. Enter the pairing PIN (default `031-45-154`) — it's also printed in the server logs on startup along with a scannable setup code.

> **Running in Docker?** HomeKit relies on mDNS/Bonjour discovery, which the default bridge network blocks. Add `network_mode: host` to the `canvas-server` service so the accessory is discoverable (this replaces the `ports:` mapping).

The pairing PIN, accessory username, and HAP port can be customized via environment variables:

| Variable | Default | Notes |
| --- | --- | --- |
| `NITRO_HOMEKIT_PINCODE` | `031-45-154` | Pairing PIN shown in the Home app |
| `NITRO_HOMEKIT_USERNAME` | `CA:11:A5:00:00:01` | Must be a valid hex MAC-style address |
| `NITRO_HOMEKIT_PORT` | `47129` | TCP port the accessory listens on |

> Pairing state is stored under `data/hap`. Delete that folder to reset pairing, then re-add the accessory in Home.

## Docker Hub

The Docker image is available at [moifort/bloomin8](https://hub.docker.com/r/moifort/bloomin8).
