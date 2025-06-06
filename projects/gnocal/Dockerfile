ARG GO_VERSION=1.24.3
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN go build -v -o /gnocal ./cmd/main.go

FROM alpine:3.22
RUN apk add --no-cache ca-certificates

COPY --from=builder /gnocal /usr/local/bin/
CMD ["gnocal"]
