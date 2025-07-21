.PHONY: dev clean down test security-scan pull-data tidy fmt vet lint

clean: down
	docker-compose down -v --remove-orphans
	rm -rf data/*

dev: down
	docker-compose up --build

down:
	docker-compose down --remove-orphans

test:
	go test ./... -v -race

security-scan:
	@which gosec > /dev/null || (echo "Installing gosec..." && go install github.com/securego/gosec/v2/cmd/gosec@latest)
	gosec ./...

pull-data:
	@echo "Checking AWS CLI availability..."
	@which aws > /dev/null || (echo "Error: AWS CLI not found. Please install it first." && exit 1)
	@echo "Exporting data from MinIO..."
	@mkdir -p data/export
	@AWS_ACCESS_KEY_ID=minioadmin \
	 AWS_SECRET_ACCESS_KEY=minioadmin123 \
	 AWS_REGION=us-east-1 \
	 aws s3 sync s3://gnolinker-data data/export/ \
	   --endpoint-url http://localhost:9000 \
	   --no-verify-ssl \
	   --delete || (echo "Error: Failed to sync data. Make sure MinIO is running (make dev)" && exit 1)
	@echo "✅ Data exported to data/export/"
	@echo "📁 Contents:"
	@find data/export -type f 2>/dev/null | head -20 || echo "   (no files found)"

fmt:
	go fmt ./...

vet:
	go vet ./...

lint:
	@which golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	golangci-lint run

tidy: fmt vet lint
	go mod tidy
