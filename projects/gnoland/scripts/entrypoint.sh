#!/bin/bash
set -e

case "$1" in
  dev)
    # Run in development mode
    echo "Starting in development mode..."
    gnodev -v \
      -web-listener 0.0.0.0:8888 \
      -node-rpc-listener 0.0.0.0:26657 \
      -web-home /r/labs000/home \
      -balance-file /gnoroot/gno.land/genesis/balances_overlay.txt
    ;;
  
  staging)
    # Run in staging mode (the current production configuration)
    echo "Starting in staging mode..."
    gnodev staging -v \
      -web-listener 0.0.0.0:8888 \
      -node-rpc-listener 0.0.0.0:26657 \
      -chain-id labsnet1 \
      -web-home /r/labs000/home \
      -balance-file /gnoroot/gno.land/genesis/balances_overlay.txt
    ;;
  
  *)
    # Run whatever command is passed
    echo "Running custom command:" "$@"
    exec "$@"
    ;;
esac