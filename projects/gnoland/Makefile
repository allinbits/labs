.PHONY: dev staging test test-all build build-test down

build:
	docker compose build

build-no-cache:
	docker compose build --no-cache

build-test:
	docker build -f Dockerfile_testrunner -t gnoland-testrunner .

down:
	docker compose down --remove-orphans -v

dev: down build
	docker compose up

staging: down build
	docker compose run --rm gnodev-labs staging

fmt:
	gno fmt ./... -w

# Pass test path to docker using testrunner
test: build-test
	@if [ -z "$(path)" ]; then \
		echo "Usage: make test path=gno.land/r/linker000/mockevent/v1"; \
	else \
		docker run --rm gnoland-testrunner gno test -v /gnoroot/examples/$(path); \
	fi

deploy-labsnet:
	@echo "Deploying labsnet to fly.io..."
	fly deploy --remote-only

deploy-indexer:
	@echo "Deploying indexer to fly.io..."
	@cd tx-indexer && fly deploy --remote-only

deploy-all: deploy-labsnet deploy-indexer
	@echo "All deployments completed."