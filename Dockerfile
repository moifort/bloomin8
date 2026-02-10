FROM oven/bun:1.2.21-alpine AS build

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .
RUN bun run build

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
ENV DATA_DIR=/data
ENV NITRO_CANVAS_URL=http://192.168.0.174
ENV NITRO_SERVER_URL=http://192.168.0.165:3000
ENV NITRO_CRON_INTERVAL_IN_HOURS=3

EXPOSE 3000

CMD ["bun", "run", ".output/server/index.mjs"]
