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

# runtime image
FROM alpine:3.21

WORKDIR /gnoroot
ENV GNOROOT="/gnoroot"
RUN apk add --no-cache ca-certificates bash

# Copy binaries from builder
COPY --from=builder /go/bin/gno /usr/local/bin/
COPY --from=builder /go/bin/gnokey /usr/local/bin/
COPY --from=builder /go/bin/gnodev /usr/local/bin/

COPY --from=builder /gnoroot /gnoroot

# labs specific modifications

# copy labs balances and append to the genesis_balances
COPY genesis/appended_genesis_balances.txt /gnoroot/gno.land/genesis/appended_genesis_balances.txt
RUN cat /gnoroot/gno.land/genesis/appended_genesis_balances.txt >> /gnoroot/gno.land/genesis/genesis_balances.txt

COPY gno.land /gnoroot/examples/gno.land

RUN ls -alh /gnoroot/examples/gno.land/r/linker000

EXPOSE 8888 26656 26657

ENTRYPOINT ["gnodev"]
CMD ["-v"]