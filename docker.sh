#!/bin/bash

. ./docker_functions.sh

clean

DOCKER_COMPOSE_FILE="docker-compose.yaml"


echo -e "\033[0;32m
 _____             _      _____ _     _
|  __ \           | |    |_   _| |   | |
| |  | | ___   ___| | __   | | | |_  | |
| |  | |/ _ \ / __| |/ /   | | | __| | |
| |__| | (_) | (__|   <   _| |_| |_  |_|
|_____/ \___/ \___|_|\_\ |_____|\__| (_)

"

read -p "Enter your project name: " project

PROJECT_SLUGGED=$(echo "$project" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr A-Z a-z)

if [ -z "$PROJECT_SLUGGED" ]
then
  error_message "You must fill a project name"
fi

read -p "Choose your SF version (5, 6, 7): " SF_VERSION
SF_VERSION="${SF_VERSION:0:1}"
SF_VERSION=${SF_VERSION:-7}
if [[ "$SF_VERSION" > 7  ||  "$SF_VERSION" < 5 ]]
then
  echo $SF_VERSION
  error_message "Version 5, 6 ou 7"
fi

printf "\n\nHere are the nginx port(s) in use:"
get_ports nginx

read -p "Specify a port to use for nginx [80]:" NGINX_PORT
NGINX_PORT=${NGINX_PORT:-80}

printf "\n\nChoose services to install:\n\n"

read -p "MariaDB (y/n):" doMariaDb

dependencies=()

if [ "$(echo "$doMariaDb" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
  dependencies[${#dependencies[*]}]="db"
  echo "Here are the db port(s) in use:"
  get_ports db

  read -p "Specify a port to use for MariaDb [3306]:" MARIA_DB_PORT
  MARIA_DB_PORT=${MARIA_DB_PORT:-3306}
fi

read -p "Redis (y/n):" doRedis

if [ "$(echo "$doRedis" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
  dependencies[${#dependencies[*]}]="redis"
  echo "Here are the redis port(s) in use:"
  get_ports redis

  read -p "Specify a port to use for redis [6379]:" redisPort
  redisPort=${redisPort:-6379}
fi

apply_project $PROJECT_SLUGGED $NGINX_PORT $SF_VERSION $MARIA_DB_PORT

printf "# Prefix $project\nversion: \"2.4\"\n" > $DOCKER_COMPOSE_FILE
printf "services:" >> $DOCKER_COMPOSE_FILE


printf "
  # SERVER PHP-FPM
  php-fpm:
    networks:
      default: { }
    build:
      context: ./docker/php-fpm
      dockerfile: Dockerfile" >> $DOCKER_COMPOSE_FILE

if [ ${#dependencies[@]} != "0" ]
then
echo "${#tableau_indi[@]}"
printf "
    links:" >> $DOCKER_COMPOSE_FILE
  for mot in ${dependencies[*]}
  do
    printf "\n      - $mot" >> $DOCKER_COMPOSE_FILE;
  done
fi

printf "
    working_dir: /var/www/html/
    volumes:
      - ./app/$PROJECT_SLUGGED:/var/www/html:cached
    tty: true

  # NGINX
  nginx:
    image: nginx
    links:
      - php-fpm
    depends_on:
      - php-fpm
    working_dir: /var/www/html
    ports:
      - $NGINX_PORT:80
    volumes:
      - ./docker/nginx/conf.d/sites-enabled/$PROJECT_SLUGGED/back.conf:/etc/nginx/conf.d/back.conf:ro
      - nginx-log:/var/log/nginx
    volumes_from:
      - php-fpm
    networks:
      default:
        aliases:
          - $PROJECT_SLUGGED.localhost
          - www.$PROJECT_SLUGGED.localhost
" >> $DOCKER_COMPOSE_FILE


if [ "$(echo "$doMariaDb" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
	printf "
  # DATABASE
  db:
    image: mariadb:10.6.10
    ports:
      - $MARIA_DB_PORT:3306
    environment:
      MYSQL_USER: root
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - db-data:/var/lib/mysql" >> $DOCKER_COMPOSE_FILE
fi

if [ "$(echo "$doRedis" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
	printf "
  # REDIS
  redis:
    image: redis
    ports:
      - $redisPort:6379
    volumes:
      - redis-data:/data" >> $DOCKER_COMPOSE_FILE
fi


printf "\nvolumes:
  nginx-log:
    driver: local" >> $DOCKER_COMPOSE_FILE
if [ "$(echo "$doMariaDb" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
	printf "
  db-data:
    driver: local" >> $DOCKER_COMPOSE_FILE
fi
if [ "$(echo "$doRedis" | tr '[:upper:]' '[:lower:]')" = "y" ]
then
	printf "
  redis-data:
    driver: local\n" >> $DOCKER_COMPOSE_FILE
fi