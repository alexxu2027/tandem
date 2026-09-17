# Tandem - developer task runner.
#
#   make help      list every target
#   make setup     one-time local setup
#   make up        start Postgres/PostGIS
#   make backend   run the API
#   make frontend  run the web app
#
# Requires: uv, pnpm, docker. On Windows use WSL, Git Bash with GNU make, or run
# the underlying commands listed in README.md directly.

SHELL := /bin/bash
.DEFAULT_GOAL := help

BACKEND  := backend
FRONTEND := frontend
COMPOSE  := docker compose

.PHONY: help setup setup-backend setup-frontend env up down restart logs ps \
        backend frontend migrate migration downgrade db-shell psql \
        test test-backend lint lint-backend lint-pipelines lint-frontend \
        format typecheck build clean reset

## ---------------------------------------------------------------------------
## Help
## ---------------------------------------------------------------------------

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## ---------------------------------------------------------------------------
## Setup
## ---------------------------------------------------------------------------

setup: env setup-backend setup-frontend ## Install all dependencies and create .env
	@echo ""
	@echo "Setup complete. Next:  make up  &&  make migrate  &&  make backend"

env: ## Create .env from .env.example if it does not exist
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env from .env.example"; \
	else \
		echo ".env already exists, leaving it alone"; \
	fi

setup-backend: ## Install backend dependencies (uv)
	cd $(BACKEND) && uv sync

setup-frontend: ## Install frontend dependencies (pnpm)
	cd $(FRONTEND) && pnpm install

## ---------------------------------------------------------------------------
## Local infrastructure
## ---------------------------------------------------------------------------

up: ## Start PostgreSQL + PostGIS in the background
	$(COMPOSE) up -d db
	@echo "Waiting for Postgres to become healthy..."
	@until [ "$$($(COMPOSE) ps -q db | xargs docker inspect -f '{{.State.Health.Status}}')" = "healthy" ]; do \
		sleep 1; \
	done
	@echo "Postgres is ready on localhost:$${POSTGRES_PORT:-5432}"

down: ## Stop all containers (data volume is preserved)
	$(COMPOSE) down

restart: down up ## Restart the database

logs: ## Tail container logs
	$(COMPOSE) logs -f

ps: ## Show container status
	$(COMPOSE) ps

db-shell psql: ## Open a psql shell in the database container
	$(COMPOSE) exec db psql -U $${POSTGRES_USER:-tandem} -d $${POSTGRES_DB:-tandem}

## ---------------------------------------------------------------------------
## Run
## ---------------------------------------------------------------------------

backend: ## Run the FastAPI dev server on :8000
	cd $(BACKEND) && uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

frontend: ## Run the Next.js dev server on :3000
	cd $(FRONTEND) && pnpm dev

## ---------------------------------------------------------------------------
## Database migrations
## ---------------------------------------------------------------------------

migrate: ## Apply all pending Alembic migrations
	cd $(BACKEND) && uv run alembic upgrade head

migration: ## Autogenerate a migration:  make migration m="add stations"
	@if [ -z "$(m)" ]; then echo 'Usage: make migration m="message"'; exit 1; fi
	cd $(BACKEND) && uv run alembic revision --autogenerate -m "$(m)"

downgrade: ## Roll back the most recent migration
	cd $(BACKEND) && uv run alembic downgrade -1

## ---------------------------------------------------------------------------
## Quality
## ---------------------------------------------------------------------------

test: test-backend ## Run all tests

test-backend: ## Run the backend pytest suite
	cd $(BACKEND) && uv run pytest

lint: lint-backend lint-pipelines lint-frontend ## Lint everything

lint-backend: ## Ruff lint + format check on backend/
	cd $(BACKEND) && uv run ruff check . && uv run ruff format --check .

lint-pipelines: ## Ruff lint + format check on pipelines/ and ml/
	uv run --project $(BACKEND) ruff check pipelines ml
	uv run --project $(BACKEND) ruff format --check pipelines ml

lint-frontend: ## ESLint + TypeScript type check
	cd $(FRONTEND) && pnpm lint && pnpm typecheck

format: ## Auto-fix formatting and lint issues
	cd $(BACKEND) && uv run ruff check --fix . && uv run ruff format .
	uv run --project $(BACKEND) ruff check --fix pipelines ml
	uv run --project $(BACKEND) ruff format pipelines ml
	cd $(FRONTEND) && pnpm lint:fix

typecheck: ## TypeScript type check only
	cd $(FRONTEND) && pnpm typecheck

build: ## Production build of the frontend
	cd $(FRONTEND) && pnpm build

## ---------------------------------------------------------------------------
## Cleanup
## ---------------------------------------------------------------------------

clean: ## Remove build artifacts and caches
	rm -rf $(FRONTEND)/.next $(FRONTEND)/out
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +

reset: ## DESTRUCTIVE: drop the database volume and all its data
	@read -p "This deletes all local database data. Continue? [y/N] " ok; \
	if [ "$$ok" = "y" ] || [ "$$ok" = "Y" ]; then \
		$(COMPOSE) down -v; \
		echo "Database volume removed. Run 'make up && make migrate' to rebuild."; \
	else \
		echo "Aborted."; \
	fi
