FROM cgr.dev/chainguard/go:latest AS builder
WORKDIR /app
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o gnolinker ./cmd


FROM cgr.dev/chainguard/static:latest
WORKDIR /app
COPY --from=builder /app/gnolinker .
ENTRYPOINT ["/app/gnolinker"]