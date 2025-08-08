#!/bin/bash
set -e

exec gnofaucet serve captcha \
  -chain-id "$CHAIN_ID" \
  -remote "$REMOTE" \
  -mnemonic "$FAUCET_MNEMONIC" \
  -captcha-secret "$RECAPTCHA_SECRET"