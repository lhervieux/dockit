#
# PARAMETERS
#

DOCKER_COMPOSE            = docker compose
DOCKER                    = docker
DOCKER_PREFIX             = dockit-

DOCKER_PS_A               = $(DOCKER) ps -a
DOCKER_PS_AQ              = $(DOCKER) ps -a -q
DOCKER_PROJ_CONT          = $$($(DOCKER_PS_A) |awk '$$NF ~ /$(DOCKER_PREFIX)/ {print $$1}')

HAS_DB               	  = 0
EXEC_DB               	  = $(DOCKER) exec $(DOCKER_PREFIX)-db-1 sh -c

WWW_PHP_CONTAINER         = $(DOCKER_PREFIX)-php-fpm-1
EXEC_WWW_PHP_TTY          = $(DOCKER) exec -it $(WWW_PHP_CONTAINER) zsh -c
EXEC_WWW_PHP              = $(DOCKER) exec -i $(WWW_PHP_CONTAINER) zsh -c

COMPOSER				  = composer
PHP_CONSOLE_EXEC          = php bin/console

PROJECT_NAME			  = $(subst dockit-,,$(DOCKER_PREFIX))

#
# ANY
#

help:
	clear
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/' | grep -v '@'

## ———————————————————————————————————— 🤘 DOCK-IT! 🤘 —————————————————————————————————————————————————————————
create: ## Create your project
	$(MAKE) rm
	bash docker.sh
	$(MAKE) build
	$(MAKE) install_symfony
	$(MAKE) info

check_project: ## Do project created
ifeq ($(DOCKER_PREFIX), dockit-)
	$(error DOCKER_PREFIX is not set, create project first)
endif

info:
	@$(MAKE) check_project
	@echo "\033[0;32mNom du projet créé: $(PROJECT_NAME)"
	@echo "Url: http://www.$(PROJECT_NAME).localhost:"
ifeq ($(HAS_DB), 1)
	@echo "Url DB: mysql://root:root@$(DOCKER_PREFIX)-db-1:/$(PROJECT_NAME)"
endif
	@echo "\033[0m"

## ———————————————————————————————————— 🐳 DOCKER 🐳 ————————————————————————————————————————————————————————
install: ## Install docker project
	$(MAKE) build
	$(MAKE) vendor
	$(MAKE) assets_build

start: ## Stop all docker project containers
	@$(MAKE) check_project
	$(DOCKER_COMPOSE) -p $(DOCKER_PREFIX) up -d --remove-orphans --no-recreate

stop: ## Stop all docker project containers
	$(DOCKER) stop $(DOCKER_PROJ_CONT)

build: ## Stop all docker project containers
	$(MAKE) check_project
	-$(MAKE) rm
	$(DOCKER_COMPOSE) -p $(DOCKER_PREFIX) build
	$(MAKE) start

rm: ## Delete all docker project containers
	-$(MAKE) stop
	-$(DOCKER) rm $(DOCKER_PROJ_CONT)
	-docker network rm $(docker network ls | grep dockit | awk '{print $1}')

## ———————————————————————————————————— 🧙 Composer 🧙 ——————————————————————————————————————————————————————

vendor: ## WWW - Composer install
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "COMPOSER_MEMORY_LIMIT=-1 composer install --no-interaction"

assets_install: ## WWW - Install assets dependencies
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "exec pnpm config set registry https://registry.npmjs.org/"
	$(EXEC_WWW_PHP_TTY) "exec pnpm install"

assets_build: ## WWW - Install assets for prod
	$(MAKE) assets_install
	$(EXEC_WWW_PHP_TTY) "exec pnpm run build"

## ———————————————————————————————————— 🦭 MariaDB 🦭 ———————————————————————————————————————————————————————

@check_db: ## Do DB created
	@$(MAKE) check_project
ifeq ($(HAS_DB), 0)
	$(error DB not defined)
endif

@db_create: ## API - DB - Create
	@$(MAKE) check_db
	-$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) doctrine:database:create --if-not-exists"

@db_schema_drop: ## API - DB - Drop schema
	@$(MAKE) check_db
	-$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) doctrine:schema:drop --force --full-database"

@db_schema_create: ## API - DB - Create schema
	@$(MAKE) check_db
	$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) doctrine:schema:create"

@db_migrate: ## API - DB - Apply migrations
	@$(MAKE) check_db
	$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) doctrine:migrations:diff -n"
	$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) doctrine:migrations:migrate -n"

## ———————————————————————————————————— 🎵 Symfony 🎵 ———————————————————————————————————————————————————————
install_symfony: ## WWW - Install Symfony project
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "$(COMPOSER) create-project symfony/skeleton:\"$(SYMFONY_VERSION).*\" ."
ifeq ($(HAS_DB), 1)
	$(EXEC_WWW_PHP_TTY) "$(COMPOSER) require symfony/orm-pack"
endif
	sudo chown -R $(USER) app/$(PROJECT_NAME)

cache_clear: ## WWW - Clear cache
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) cache:clear"

cache_warmup: ## WWW - Warmup cache
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "$(PHP_CONSOLE_EXEC) cache:warmup"

cli: ## WWW - Access docker cli
	@$(MAKE) check_project
	$(EXEC_WWW_PHP_TTY) "stty columns `tput cols`; stty rows `tput lines`; exec zsh;"
