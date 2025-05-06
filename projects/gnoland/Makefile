.PHONY: dev staging test

dev:
	gnodev -v -resolver root=${GNOROOT}/examples -resolver root=${PWD}

staging:
	gnodev staging -v ${GNOROOT}/examples ${PWD} 

# Pass test path to docker compose using bash as entrypoint
test:
	@if [ -z "$(path)" ]; then \
		echo "Usage: make test path=gno.land/r/linker000/mockevent/v1"; \
	else \
		docker compose run --rm --entrypoint="/bin/bash" gnodev-labs -c "gno test -v /gnoroot/examples/$(path)"; \
	fi