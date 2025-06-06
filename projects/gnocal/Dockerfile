ARG GO_VERSION=1.24.3
FROM golang:${GO_VERSION}-bookworm as builder

WORKDIR /usr/src/app
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY . .
RUN go build -v -o /gnocal ./cmd/main.go


FROM debian:bookworm

COPY --from=builder /gnocal /usr/local/bin/
CMD ["gnocal"]
