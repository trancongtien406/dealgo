# syntax=docker/dockerfile:1
# DealGo API / worker / migrate images (DEC-PROD-053). Build: docker build --target api ./backend
# No secrets are baked in: every key comes from the runtime environment.

FROM node:24-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

FROM deps AS build
COPY . .
RUN npx prisma generate && npx nest build && npm prune --omit=dev --ignore-scripts

# One-shot: `prisma migrate deploy` (keeps the Prisma CLI, which is a dev dependency).
FROM deps AS migrate
# `npm ci --ignore-scripts` skips the Prisma engine download, and the image has no
# OpenSSL; `migrate deploy` needs both, and the `node` user cannot write node_modules.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm rebuild @prisma/engines prisma
COPY prisma ./prisma
COPY prisma.config.ts tsconfig.json ./
ENV NODE_ENV=production
USER node
CMD ["npx", "prisma", "migrate", "deploy"]

FROM node:24-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    LOG_FORMAT=json
COPY --from=build --chown=node:node /app/package.json ./
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
USER node

FROM runtime AS worker
CMD ["node", "dist/workers/worker-main.js"]

FROM runtime AS api
EXPOSE 3001
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=4 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3001)+'/health/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/main.js"]
