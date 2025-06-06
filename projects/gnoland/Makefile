.PHONY: dev staging test test-all build down

build:
	docker compose build

build-no-cache:
	docker compose build --no-cache

down:
	docker compose down --remove-orphans -v

dev: down build
	docker compose up

staging: down build
	docker compose run --rm gnodev-labs staging

# Pass test path to docker compose using bash as entrypoint
test: build
	@if [ -z "$(path)" ]; then \
		echo "Usage: make test path=gno.land/r/linker000/mockevent/v1"; \
	else \
		docker compose run --rm gnodev-labs gno test -v /gnoroot/examples/$(path); \
	fi

# Add paths that you want tested here
test-all: build
	@make test path=gno.land/r/linker000/... && \
	make test path=gno.land/p/eve000/...