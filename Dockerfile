# ---- builder ----
# Alpine, extended
FROM ghcr.io/gohugoio/hugo:v0.152.2 AS builder
WORKDIR /src
COPY . .

# Allow the Hugo build to be configured at build time so the generated site can
# be previewed locally with the correct baseURL.
ARG HUGO_BASEURL=https://thomasmoyer.org/
ARG HUGO_ENVIRONMENT=production
ENV HUGO_ENVIRONMENT=${HUGO_ENVIRONMENT}
RUN hugo --minify --environment "${HUGO_ENVIRONMENT}" --baseURL "${HUGO_BASEURL}"

# ---- web ----
FROM caddy:2.10-alpine
# Serve static files from /usr/share/caddy
COPY --from=builder /src/public/ /usr/share/caddy/
# Basic production Caddyfile; Traefik will still be your edge proxy.
# We just serve static content on 8080 for Traefik to forward to.
RUN printf ":8080\nroot * /usr/share/caddy\nfile_server\n" > /etc/caddy/Caddyfile
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/ >/dev/null || exit 1