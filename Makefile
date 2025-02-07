# Nome do arquivo: Makefile

.DEFAULT_GOAL := help

# Alvos
.PHONY: setup setup_here help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Alvo para criar a rede se não existir
setup: ## Cria Makefile na pasta pai 
	cp fileMake ../Makefile

# Alvo para subir os serviços
setup_here: ## Cria Makefile na pasta atual
	cp Makefile setupMakefile
	mv fileMake Makefile
