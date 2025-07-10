.PHONY: install test

# Default target
all: install

# Install to GOPATH/bin
install:
	go install -ldflags="-s -w" ./cmd/gnoquery

# Run tests
test:
	go test -v ./...
