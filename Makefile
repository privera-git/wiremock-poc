COMPOSE := docker compose
REDOCLY := redocly/cli:2.76.0
REPORT  := tests/target/karate-reports/karate-summary.html
PORT    ?= 8080

.DEFAULT_GOAL := help
.PHONY: help install run stop logs test lint check clean check-docker

help: ## Muestra los comandos disponibles
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

check-docker:
	@docker info >/dev/null 2>&1 || (echo "Docker no está corriendo. Inicia Docker Desktop y reintenta." && exit 1)

install: check-docker ## Construye las imágenes (mock + Karate) desde cero
	$(COMPOSE) --profile test build

run: check-docker ## Levanta el mock en http://localhost:$(PORT) (PORT=9090 make run para cambiarlo)
	MOCK_PORT=$(PORT) $(COMPOSE) up -d --build --wait wiremock
	@echo "Mock disponible en http://localhost:$(PORT)  ·  stubs cargados: http://localhost:$(PORT)/__admin/mappings"

stop: ## Detiene el mock
	$(COMPOSE) --profile test down

logs: ## Muestra el log del mock (solicitudes recibidas)
	$(COMPOSE) logs -f wiremock

test: check-docker ## Ejecuta las pruebas Karate contra el mock y abre el reporte
	$(COMPOSE) --profile test build -q
	$(COMPOSE) --profile test run --rm karate; status=$$?; \
	  $(COMPOSE) --profile test down >/dev/null 2>&1; \
	  if [ -z "$$CI" ]; then open $(REPORT) 2>/dev/null || echo "Reporte: $(REPORT)"; fi; \
	  exit $$status

lint: check-docker ## Valida el contrato OpenAPI (Redocly)
	docker run --rm -v "$(CURDIR):/spec" -w /spec $(REDOCLY) lint openapi/pagos.yaml

check: lint test ## Lo mismo que ejecuta CI: contrato + pruebas

clean: stop ## Elimina reportes e imágenes locales
	rm -rf tests/target
	-docker image rm wiremock-poc:local wiremock-poc-karate >/dev/null 2>&1
