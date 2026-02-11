# syntax=docker/dockerfile:1.7

FROM oven/bun:1.2.21-alpine AS build
WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY . .
RUN bun run build

FROM oven/bun:1.2.21-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000
ENV NITRO_SERVER_URL=http://127.0.0.1:3000

COPY --from=build /app/.output ./.output
RUN cd .output/server && bun install --production

RUN addgroup -S app && adduser -S app -G app \
  && mkdir -p /app/data/images /app/data/playlist \
  && chown -R app:app /app

USER app

EXPOSE 3000

CMD ["bun", ".output/server/index.mjs"]
