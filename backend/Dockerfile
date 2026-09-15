FROM node:24.14.0-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json tsconfig.build.json drizzle.config.ts ./
COPY src ./src
RUN npm run build

FROM node:24.14.0-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY drizzle ./drizzle
COPY --from=build /app/dist ./dist
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod 0555 ./docker-entrypoint.sh && mkdir -p /app/data/photos

EXPOSE 3000
ENTRYPOINT ["./docker-entrypoint.sh"]
