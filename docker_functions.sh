#!/bin/bash

clean()
{
  clear
  rm -rf ./docker/nginx/conf.d/sites-enabled/*
  rm -rf ./app/*
  sed -i '/DOCKER_PREFIX             =/d' ./Makefile
  sed -i 's/localhost:[0-9]./localhost:/g' ./Makefile
  sed -i 's/-db-1:[0-9]*/-db-1:/g' ./Makefile
  sed -i -e "/DOCKER                    = docker/a DOCKER_PREFIX             = dockit-" ./Makefile
  sed -i 's/HAS_DB               	  = 1/HAS_DB               	  = 0/g' ./Makefile
  sed -i '/SYMFONY_VERSION			  =/d' ./Makefile
  if ! grep -q "@db_" Makefile
  then
    sed -i -e "s/db_/@db_/g" ./Makefile
  fi
}

get_ports()
{
  CONTAINER_TYPE=$1

  echo -e "\033[0;31m" && docker ps --format "table {{.Names}} | {{.Ports}}" | grep $CONTAINER_TYPE | awk '{print $NF}' | grep -Po "[0-9]*" | sort -u && echo -e "\033[0;32m"
}

error_message()
{
  MESSAGE=$1
  echo -e "\033[0;31m$MESSAGE"
  echo -e "Exiting...\033[0;32m"
  exit
}

apply_project()
{
  PROJECT_SLUGGED=$1
  NGINX_PORT=$2
  SF_VERSION=$3
  MARIA_DB_PORT=$4

  mkdir ./docker/nginx/conf.d/sites-enabled/$PROJECT_SLUGGED
  mkdir ./app/$PROJECT_SLUGGED
  cp ./docker/nginx/conf.d/back.conf ./docker/nginx/conf.d/sites-enabled/$PROJECT_SLUGGED

  sed -i -e "s/domain_name/www.$PROJECT_SLUGGED.localhost/g" docker/nginx/conf.d/sites-enabled/$PROJECT_SLUGGED/back.conf
  sed -i -e "s/= dockit-/= dockit-$PROJECT_SLUGGED/g" Makefile
  sed -i -e "s/localhost:/localhost:$NGINX_PORT/g" Makefile
  sed -i -e "/PROJECT_NAME			  =/a SYMFONY_VERSION			  =$SF_VERSION" Makefile

  if [ ! -z "$MARIA_DB_PORT" ]
  then
    sed -i -e "s/@db_/db_/g" Makefile
    sed -i 's/HAS_DB               	  = 0/HAS_DB               	  = 1/g' Makefile
    sed -i -e "s/-db-1:/-db-1:$MARIA_DB_PORT/g" Makefile
  fi
}
