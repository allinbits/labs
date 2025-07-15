.PHONY: dev clean down test security-scan

clean: down
	docker-compose down -v --remove-orphans
	rm -rf data/*

dev: down
	docker-compose up --build

down:
	docker-compose down --remove-orphans

test:
	go test ./... -v

security-scan:
	@which gosec > /dev/null || (echo "Installing gosec..." && go install github.com/securego/gosec/v2/cmd/gosec@latest)
	gosec ./...
