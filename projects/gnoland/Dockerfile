FROM ghcr.io/gnolang/gno/gnodev:0.0.1-5fa440aff-master-amd64
RUN apk add --no-cache ca-certificates bash

# import gno code from this repository
COPY gno.land /gnoroot/examples/gno.land

# import seeded balances
COPY genesis/balances_overlay.txt /gnoroot/gno.land/genesis/balances_overlay.txt

# import entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh

EXPOSE 8888 8889 26656 26657 80 443
ENTRYPOINT ["/entrypoint.sh"]
