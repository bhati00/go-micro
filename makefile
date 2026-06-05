SHELL := /bin/bash
.RECIPEPREFIX := >

ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PROJECT_DIR := $(ROOT_DIR)/project
FRONTEND_DIR := $(ROOT_DIR)/front-end
BROKER_DIR := $(ROOT_DIR)/broker-service
AUTH_DIR := $(ROOT_DIR)/authentication-service
LOGGER_DIR := $(ROOT_DIR)/logger-service
MAILER_DIR := $(ROOT_DIR)/mail-service

FRONT_END_BINARY := frontApp
BROKER_BINARY := brokerApp
AUTH_BINARY := authApp
LOGGER_BINARY := loggerServiceApp
MAILER_BINARY := mailerApp
LISTENER_BINARY := listenerApp

.PHONY: up up_build down build_broker build_auth build_logger build_front build_mailer start stop

COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo ""; fi)

check_compose:
> @if [ -z "$(COMPOSE)" ]; then \
> 	echo "Error: neither 'docker compose' nor 'docker-compose' is available."; \
> 	exit 1; \
> fi

## up: starts all containers in the background without forcing build
up: check_compose
> @echo "Starting Docker images..."
> cd "$(PROJECT_DIR)" && $(COMPOSE) up -d --remove-orphans
> @echo "Docker images started!"

## up_build: builds all service binaries and starts docker compose
up_build: check_compose build_broker build_auth build_logger build_mailer build_listener build_front
> @echo "Stopping docker images (if running)..."
> cd "$(PROJECT_DIR)" && $(COMPOSE) down --remove-orphans
> @echo "Building (when required) and starting docker images..."
> cd "$(PROJECT_DIR)" && $(COMPOSE) up --build -d --remove-orphans
> @echo "Docker images built and started!"

## down: stop docker compose
down: check_compose
> @echo "Stopping docker compose..."
> cd "$(PROJECT_DIR)" && $(COMPOSE) down --remove-orphans
> @echo "Done!"

## build_broker: builds broker binary as linux executable
build_broker:
> @echo "Building broker binary..."
> cd "$(BROKER_DIR)" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$(BROKER_BINARY)" ./cmd/api
> @echo "Done!"

## build_logger: builds logger binary as linux executable
build_logger:
> @echo "Building logger binary..."
> cd "$(LOGGER_DIR)" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$(LOGGER_BINARY)" ./cmd
> @echo "Done!"

## build_auth: builds auth binary as linux executable
build_auth:
> @echo "Building auth binary..."
> cd "$(AUTH_DIR)" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$(AUTH_BINARY)" ./cmd/api
> @echo "Done!"

## build_mailer: builds mailer binary as linux executable
build_mailer:
> @echo "Building mailer binary..."
> cd "$(MAILER_DIR)" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$(MAILER_BINARY)" ./cmd/api
> @echo "Done!"

## build_listener: builds listener binary as linux executable
build_listener:
> @echo "Building listener binary..."
> cd "$(ROOT_DIR)/listener-service" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "listenerApp" .
> @echo "Done!"	

## build_front: builds front end binary for linux
build_front:
> @echo "Building front end binary..."
> cd "$(FRONTEND_DIR)" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o "$(FRONT_END_BINARY)" ./cmd/web
> @echo "Done!"

## start: starts the front end
start: build_front
> @echo "Starting front end..."
> cd "$(FRONTEND_DIR)" && nohup ./"$(FRONT_END_BINARY)" > front-end.log 2>&1 & echo $$! > front-end.pid
> @echo "Front end started on port 8082"

## stop: stop the front end
stop:
> @echo "Stopping front end..."
> @pkill -x "$(FRONT_END_BINARY)" 2>/dev/null || true
> @rm -f "$(FRONTEND_DIR)/front-end.pid"
> @echo "Stopped front end!"