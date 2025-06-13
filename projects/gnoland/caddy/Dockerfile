FROM golang:1.24-alpine AS builder
# Install xcaddy first
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
# Build caddy with the replace-response module and specify output path explicitly
WORKDIR /build
RUN xcaddy build \
    --with github.com/caddyserver/replace-response@latest \
    --output /usr/local/bin/caddy

FROM alpine:latest

COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile

EXPOSE 8888
ENTRYPOINT [ "caddy", "run", "--config", "/etc/caddy/Caddyfile" ]