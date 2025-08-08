# gnofaucet for labsnet

We are using `gnofaucet` from the test7.2 branch wired up with reCAPTCHA protection to provide testnet GNOT tokens for developers on labsnet. The faucet is deployed on Fly.io and configured through GitHub Actions CI/CD.

Reference implementation: https://github.com/gnolang/gno/tree/chain/test7.2/contribs/gnofaucet

## Required GitHub Secrets

Configure these in Settings → Secrets and variables → Actions:

- `FLY_API_TOKEN_FAUCET`: Fly.io API token (run `flyctl tokens create`)
- `FAUCET_MNEMONIC`: Wallet mnemonic for funding
- `RECAPTCHA_SECRET`: Google reCAPTCHA secret key

## Deployment

Manual deployment:
```bash
cd projects/gnoland/faucet
flyctl deploy --app gnofaucet-labs
```

The faucet will automatically deploy via GitHub Actions when changes are pushed to `main`.
