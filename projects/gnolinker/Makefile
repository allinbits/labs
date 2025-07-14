.PHONY: dev clean down

clean: down
	docker-compose down -v --remove-orphans
	rm -rf data/*

dev: down
	docker-compose up --build

down:
	docker-compose down --remove-orphans
