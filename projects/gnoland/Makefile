.PHONY: dev staging test build down

build:
	docker compose build

down:
	docker compose down --remove-orphans -v

dev: down build
	docker compose up

staging: down build
	 docker compose run --rm gnodev-labs -v \
	 	-web-listener 0.0.0.0:8888 \
		-node-rpc-listener 0.0.0.0:26657 \
		-balance-file /gnoroot/gno.land/genesis/genesis_balances.txt \

# Pass test path to docker compose using bash as entrypoint
test:
	@if [ -z "$(path)" ]; then \
		echo "Usage: make test path=gno.land/r/linker000/mockevent/v1"; \
	else \
		docker compose run --rm --entrypoint="/bin/bash" gnodev-labs -c "gno test -v /gnoroot/examples/$(path)"; \
	fi

# Add paths that you want tested here
test-all:
	@make test path=gno.land/r/linker000/...