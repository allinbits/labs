#!/bin/bash

set -e

gnodev -v \
    -web-listener 0.0.0.0:8888 \
    -node-rpc-listener 0.0.0.0:26657 \
    -chain-id labsnet1 \
    -balance-file /gnoroot/gno.land/genesis/genesis_balances.txt &

caddy run --config /etc/caddy/Caddyfile