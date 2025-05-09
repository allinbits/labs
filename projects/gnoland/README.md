# gnoland

This is a repository meant to hold all gno.land smart contract related `p/` and `r/` files.

This has a local development environment so that you can run `make dev` and it will spin up hot-reload for `examples` as well as all the files in this directory. 

## Environment Assumptions

1) You have a local fork of `gnolang/gno` on your machine
2) You have $GNOROOT env configured to point to your fork of gno source code
3) You have `gnodev` installed. If not, please run `make install` from your fork of gno and install it first
