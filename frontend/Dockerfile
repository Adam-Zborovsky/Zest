FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /app

ARG ZEST_API_BASE_URL
RUN test -n "$ZEST_API_BASE_URL"

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=ZEST_API_BASE_URL="$ZEST_API_BASE_URL"

FROM nginx:1.27.5-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
