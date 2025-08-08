FROM ghcr.io/gnolang/gno/gnofaucet:chain-test7

RUN apk add --no-cache ca-certificates bash

# Copy the entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]