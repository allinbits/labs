FROM ghcr.io/gnolang/tx-indexer:0.5.4 AS tx-indexer

FROM cgr.dev/chainguard/static:latest

WORKDIR /var/lib/app

COPY --from=tx-indexer /tx-indexer /tx-indexer

ENTRYPOINT [ "/tx-indexer" ]
