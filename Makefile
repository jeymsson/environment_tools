.PHONY: help create-network up down destroy rebuild compose logs ps otel otel-slim otel-metrics elk k6-tests sonarqube elk-gen-password man

indent_style = tab

RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m

# Nome do projeto (usado no "ps" para listar todos os containers da stack de telemetria)
PROJECT_NAME := telemetry

# Mapeamento: palavra-chave -> arquivo(s) compose de telemetria (equivalente aos antigos "include" + "--profile" do docker-compose.telemetry.all.yml)
FILES_otel         = --env-file docker/otel/.env -f docker/otel/docker-compose.otel.yml
FILES_otel-slim    = --env-file docker/otel/.env -f docker/otel/docker-compose.otel-slim.yml
FILES_otel-metrics = --env-file docker/otel/.env -f docker/otel/docker-compose.otel-metrics.yml
FILES_k6           = -f docker/k6/docker-compose.yml
FILES_jaeger       = -f docker/jaeger/docker-compose.yml
FILES_elk          = --env-file docker/elk/.env -f docker/elk/docker-compose.yml

ALL = $(FILES_otel) $(FILES_jaeger) $(FILES_k6) $(FILES_elk) $(FILES_otel-slim) $(FILES_otel-metrics)



# --- Resolução padronizada dos arquivos de Traefik (dev|prod) por família ---
# Cada família de serviço que suporta exposição via Traefik aponta para a
# sua própria pasta de overrides. Para adicionar uma nova família, basta
# declarar aqui TRAEFIK_DIR_<familia> = caminho/para/traefik
TRAEFIK_DIR_otel         = docker/otel/traefik
TRAEFIK_DIR_otel-slim    = docker/otel/traefik
TRAEFIK_DIR_otel-metrics = docker/otel/traefik
TRAEFIK_DIR_elk          = docker/elk/traefik

# Famílias que participam da resolução de Traefik (mantém em sincronia com os TRAEFIK_DIR_* acima)
TRAEFIK_FAMILIES := otel otel-slim otel-metrics elk

# Descobre qual família foi chamada (ex: "make elk dev" -> elk; "make otel-metrics prod" -> otel-metrics)
TRAEFIK_FAMILY := $(firstword $(filter $(TRAEFIK_FAMILIES),$(MAKECMDGOALS)))
TRAEFIK_DIR    := $(TRAEFIK_DIR_$(TRAEFIK_FAMILY))

# Monta os overrides dev/prod com base na pasta resolvida acima
FILES_dev  = $(if $(TRAEFIK_DIR),-f $(TRAEFIK_DIR)/dev.yml)
FILES_prod = $(FILES_dev) $(if $(TRAEFIK_DIR),-f $(TRAEFIK_DIR)/prod.yml)

# Resolve qual arquivo de override do Traefik usar, com base no argumento dev|prod
# passado depois da família (ex: make elk prod, make otel-metrics dev)
TRAEFIK_FILES := $(if $(filter prod,$(MAKECMDGOALS)),$(FILES_prod),$(if $(filter dev,$(MAKECMDGOALS)),$(FILES_dev),))

# Palavras reservadas que não devem ser resolvidas como FILES_<palavra> ao montar ARGS,
# pois são usadas como seletor de ambiente (dev|prod), não como arquivo compose.
PROFILE_KEYWORDS := dev prod




# Captura os argumentos extras passados depois do target (ex: otel otel-slim jaeger)
# Exclui as palavras reservadas de profile, para não tentar resolver FILES_dev / FILES_prod
ARGS := $(filter-out compose logs ps $(PROFILE_KEYWORDS),$(MAKECMDGOALS))
COMPOSE_FILES := $(foreach a,$(ARGS),$(FILES_$(a)))

# Impede o Make de reclamar "No rule to make target 'otel-slim'" etc
%:
	@:

help: ## Lista os targets disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# # Como usar
# make compose otel
# make compose otel-slim
# make compose otel jaeger prometheus grafana
# make compose elk
# make logs otel-slim
# make logs elk
# make otel-metrics dev
# make otel-metrics prod
# make otel-metrics          # sem dev/prod — lgtm sobe, mas sem exposição via Traefik
# make elk dev
# make elk prod
# make elk                   # sem dev/prod — elk sobe, mas sem exposição via Traefik
# make ps
# make destroy

create-network: ## Cria a rede 'opentelemetry' se não existir
	@if ! docker network inspect opentelemetry >/dev/null 2>&1; then \
		echo "Rede 'opentelemetry' não encontrada. Criando rede..."; \
		docker network create opentelemetry; \
	fi

man: ## Mostra instruções de uso
	@echo "$(GREEN)Telemetria com OpenTelemetry.$(NC)"
	@echo "Passos a seguir:"
	@echo "."
	@echo " Setup"
	@echo "  1. Rodar $(GREEN) make create-network $(NC) (feito automaticamente pelos targets de compose)."
	@echo "  2. Subir combinando o que precisar: $(GREEN) make compose otel $(NC), $(GREEN) make compose otel-slim $(NC), etc."
	@echo "     Palavras-chave disponíveis: multipages, otel, otel-slim, jaeger, prometheus, grafana, k6, sonarqube, elk"
	@echo "."
	@echo " Administração"
	@echo "  3. Ver o que está rodando: $(GREEN) make ps $(NC)."
	@echo "  4. Caso necessário encerrar containeres, rodar $(GREEN) make down $(NC)."
	@echo "  5. Caso necessário encerrar containeres e remover volumes, rodar $(GREEN) make destroy $(NC)."
	@echo "."
	@echo " ELK"
	@echo "  6. Subir com $(GREEN) make elk $(NC) ou $(GREEN) make compose elk $(NC)."
	@echo "  7. Subir com Traefik: $(GREEN) make elk dev $(NC) ou $(GREEN) make elk prod $(NC) (usa docker/elk/traefik)."
	@echo "  8. Gerar senha com $(GREEN) make elk-gen-password $(NC)."
	@echo "."
	@echo " OTel Metrics"
	@echo "  9. Subir com Traefik: $(GREEN) make otel-metrics dev $(NC) ou $(GREEN) make otel-metrics prod $(NC) (usa docker/otel/traefik)."
	@echo "     Requer $(GREEN) docker/otel/.env $(NC) com TRAEFIK_DNS definido (ex: TRAEFIK_DNS=grafana.localhost)."
	@echo "."
	@echo "  10. Exemplos de comando:"
	@echo "      $(GREEN) make compose otel-slim $(NC)"
	@echo "      $(GREEN) make compose otel jaeger prometheus grafana $(NC)"
	@echo "      $(GREEN) make logs otel-slim $(NC)"
	@echo "      $(GREEN) make otel-metrics prod $(NC)"
	@echo "      $(GREEN) make elk dev $(NC)"

compose: create-network ## Sobe combinando arquivos: make compose otel otel-slim jaeger
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) up -d

logs: ## Logs combinando arquivos: make logs otel-slim
	docker compose -p $(PROJECT_NAME) $(COMPOSE_FILES) logs -f --tail=100

up: create-network ## Sobe todos os serviços de telemetria
	docker compose -p $(PROJECT_NAME) $(ALL) up -d

down: ## Derruba todos os serviços de telemetria
	docker compose -p $(PROJECT_NAME) $(ALL) down --remove-orphans

destroy: ## Destrói todos os serviços de telemetria (com volumes)
	@echo "$(RED)Aviso: todos os volumes serão removidos!$(NC)"
	@read -p "Tem certeza que deseja continuar? (s/n): " confirm && [ "$$confirm" = "s" ] || exit 1
	@echo "$(YELLOW) -> Iniciando destruição dos serviços de telemetria e remoção de volumes...$(NC)"
	@docker compose -p $(PROJECT_NAME) $(ALL) down -v --remove-orphans
	@echo "$(YELLOW) -> Finalizado$(NC)"
	$(MAKE) ps

otel: create-network ## Sobe aplicação com OpenTelemetry. Uso: make otel [dev|prod]
	docker compose -p $(PROJECT_NAME) $(FILES_otel) $(TRAEFIK_FILES) up -d

otel-slim: create-network ## Sobe aplicação com OpenTelemetry Slim. Uso: make otel-slim [dev|prod]
	docker compose -p $(PROJECT_NAME) $(FILES_otel-slim) $(TRAEFIK_FILES) up -d

otel-metrics: create-network ## Sobe OTel Metrics + Prometheus Exporter. Uso: make otel-metrics [dev|prod]
	docker compose -p $(PROJECT_NAME) $(FILES_otel-metrics) $(TRAEFIK_FILES) up -d

elk: create-network ## Sobe a stack ELK. Uso: make elk [dev|prod]
	docker compose -p $(PROJECT_NAME) $(FILES_elk) $(TRAEFIK_FILES) up -d

ps: ## Lista os containers da stack de telemetria (todos os arquivos)
	@echo "     $(GREEN) Docker ps da stack de telemetria ($(PROJECT_NAME)): $(NC)"
	@docker compose -p $(PROJECT_NAME) $(ALL) ps --format "table {{.Name}}\t{{.ID}}\t{{.Service}}\t{{.Image}}\t{{.State}}\t{{.Status}}"

list: ## Lista todos os containers do host em formato de tabela
	@echo "     $(GREEN) Docker ps -a (todos os containers do host): $(NC)"
	@docker ps -a --format "table {{.Names}}\t{{.ID}}\t{{.Label \"com.docker.compose.service\"}}\t{{.Label \"com.docker.compose.project\"}}\t{{.Image}}\t{{.State}}\t{{.Status}}"
