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

# Pass test path to docker using testrunner
test: build-test
	@if [ -z "$(path)" ]; then \
		echo "Usage: make test path=gno.land/r/linker000/mockevent/v1"; \
	else \
		docker run --rm gnoland-testrunner gno test -v /gnoroot/examples/$(path); \
	fi