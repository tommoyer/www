# syntax=docker/dockerfile:1.7

# ---- builder ----
FROM ghcr.io/gohugoio/hugo:v0.152.2 AS builder
WORKDIR /src
COPY . .

# Allow the Hugo build to be configured at build time so the generated site can
# be previewed locally with the correct baseURL.
ARG HUGO_BASEURL=https://moyer.wtf/
ARG HUGO_ENVIRONMENT=production
ENV HUGO_ENVIRONMENT=${HUGO_ENVIRONMENT}
RUN hugo --minify --environment "${HUGO_ENVIRONMENT}" --baseURL "${HUGO_BASEURL}"

# ---- web ----
FROM nginx:1.27-alpine AS web
COPY --from=builder /src/public/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/ >/dev/null || exit 1
