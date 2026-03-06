SHELL := /bin/bash
FRONT_END_BINARY=frontApp
BROKER_BINARY=brokerApp
AUTH_BINARY=authApp
COMPOSE_FILE=project/docker-compose.yml
DOCKER_COMPOSE=$(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif docker-compose version >/dev/null 2>&1; then echo "docker-compose"; else echo "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ${CURDIR}:${CURDIR} -w ${CURDIR} docker/compose:1.29.2"; fi)
COMPOSE=${DOCKER_COMPOSE} -f ${COMPOSE_FILE}

## check_compose: verifies an available docker compose command
check_compose:
	@if ! docker info >/dev/null 2>&1; then \
		echo "Docker daemon is not reachable."; \
		echo "Start Docker and retry."; \
		exit 1; \
	fi

## up: starts all containers in the background without forcing build
up:
	@echo "Starting Docker images..."
	@${MAKE} check_compose
	${COMPOSE} up -d
	@echo "Docker images started!"

## up_build: stops docker-compose (if running), builds all projects and starts docker compose
up_build: build_broker build_auth
	@echo "Stopping docker images (if running...)"
	@${MAKE} check_compose
	${COMPOSE} down
	@echo "Building (when required) and starting docker images..."
	${COMPOSE} up --build -d
	@echo "Docker images built and started!"

## down: stop docker compose
down:
	@echo "Stopping docker compose..."
	@${MAKE} check_compose
	${COMPOSE} down
	@echo "Done!"

## build_broker: builds the broker binary as a linux executable
build_broker:
	@echo "Building broker binary..."
	cd broker-service && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ${BROKER_BINARY} ./cmd/api
	@echo "Done!"

## build_auth: builds the auth binary as a linux executable
build_auth:
	@echo "Building auth binary..."
	cd authentication-service && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ${AUTH_BINARY} ./cmd/api
	@echo "Done!"

## build_front: builds the frone end binary
build_front:
	@echo "Building front end binary..."
	cd front-end && CGO_ENABLED=0 GOOS=linux go build -o ${FRONT_END_BINARY} ./cmd/web
	@echo "Done!"

## start: starts the front end
start: build_front
	@echo "Starting front end"
	cd front-end && ./${FRONT_END_BINARY} &

## stop: stop the front end
stop:
	@echo "Stopping front end..."
	@pkill -f "${FRONT_END_BINARY}" || true
	@echo "Stopped front end!"