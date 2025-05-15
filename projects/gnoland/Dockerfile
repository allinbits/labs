# build image
FROM golang:1.23-alpine AS builder
ENV         GNOROOT="/gnoroot"
ENV         CGO_ENABLED=0 GOOS=linux 
WORKDIR     /gnoroot
RUN         go env -w GOMODCACHE=/root/.cache/go-build

# Install git and build dependencies
RUN apk add --no-cache git make build-base

# Set working directory
WORKDIR /gnoroot

# We always want to build from a specific commit hash, for safety.
ARG COMMIT_HASH
RUN git clone --depth 1 https://github.com/gnolang/gno.git . && \
    git fetch --depth=1 origin ${COMMIT_HASH} && \
    git checkout ${COMMIT_HASH}

RUN go mod download -x

# Build the application
RUN make install

# Build caddy with replace-response module
FROM golang:1.24-alpine AS caddy-builder
RUN apk add --no-cache git
# Install xcaddy first
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
# Build caddy with the replace-response module and specify output path explicitly
WORKDIR /build
RUN xcaddy build \
    --with github.com/caddyserver/replace-response@latest \
    --output /usr/local/bin/caddy

# runtime image
FROM alpine:3.21

WORKDIR /gnoroot
ENV GNOROOT="/gnoroot"
ENV GNO_HOME="/gnoroot"
RUN apk add --no-cache ca-certificates bash

# Copy binaries from builder
COPY --from=builder /go/bin /usr/local/bin/
COPY --from=builder /gnoroot /gnoroot
# Copy the caddy binary from caddy-builder to the final image
COPY --from=caddy-builder /usr/local/bin/caddy /usr/local/bin/caddy

# import seeded balances
COPY genesis/balances_overlay.txt /gnoroot/gno.land/genesis/balances_overlay.txt

COPY gno.land /gnoroot/examples/gno.land

# Create directory for Caddy configuration
RUN mkdir -p /etc/caddy
COPY Caddyfile /etc/caddy/Caddyfile

COPY scripts/entrypoint.sh /entrypoint.sh

EXPOSE 8888 8889 26656 26657 80 443
ENTRYPOINT ["/entrypoint.sh"]
