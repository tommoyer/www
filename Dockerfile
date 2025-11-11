# ---- builder ----
# Alpine, extended
FROM docker.io/hugomods/hugo:ext-alpine-v0.152.2 AS builder
WORKDIR /src
COPY . .
# set your baseURL if needed: hugo --minify --baseURL https://example.com
RUN hugo --minify

# ---- web ----
FROM caddy:2.10-alpine
# Serve static files from /usr/share/caddy
COPY --from=builder /src/public /usr/share/caddy
# Basic production Caddyfile; Traefik will still be your edge proxy.
# We just serve static content on 8080 for Traefik to forward to.
RUN printf ":{env.PORT}\nroot * /usr/share/caddy\nfile_server\n" > /etc/caddy/Caddyfile
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/ >/dev/null || exit 1