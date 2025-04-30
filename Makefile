# Makefile

# Makefile for the labs project

.PHONY: all build test clean

all: build

build:
	go build ./...

test:
	go test ./...

clean:
	go clean
	rm -rf ./bin/*