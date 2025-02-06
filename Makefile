# Nome do arquivo: Makefile

# Alvos
.PHONY: setup setup_here

# Alvo para criar a rede se não existir
setup:
	cp fileMake ../Makefile

# Alvo para subir os serviços
setup_here:
	cp Makefile setupMakefile
	mv fileMake Makefile
