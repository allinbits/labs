FROM ghcr.io/gnolang/gno/gnodev:0.0.1-50a4317de-master

RUN apk add --no-cache ca-certificates bash

# import seeded balances
COPY genesis/balances_overlay.txt /gnoroot/gno.land/genesis/balances_overlay.txt
COPY gno.land /gnoroot/examples/gno.land
COPY scripts/entrypoint.sh /entrypoint.sh

EXPOSE 8888 26657
ENTRYPOINT ["/entrypoint.sh"]
