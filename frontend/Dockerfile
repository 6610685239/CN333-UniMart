# ── Stage 1: Build Flutter web ───────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY . .

RUN flutter pub get

ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY

RUN flutter build web \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# ── Stage 2: Serve with nginx ─────────────────────────────────────────────────
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
