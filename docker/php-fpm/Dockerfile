FROM php:8.2-fpm AS base

# Install Packages
RUN apt-get update -y --fix-missing \
    && apt-get install -y --no-install-recommends build-essential \
    procps \
    apt-transport-https \
    autoconf \
    libssl-dev \
    libssh-dev \
    zlib1g-dev \
    curl \
    git \
    unzip \
    libxml2-dev \
    libpq-dev \
    libzip-dev \
    vim \
    zsh \
    make \
    g++ \
    gcc \
    gnupg \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libicu-dev \
    libwebp-dev \
    libc-dev \
    openssl \
    pkg-config \
    libmcrypt-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pecl install apcu

RUN docker-php-ext-install -j"$(nproc)" zip \
    opcache \
    intl \
    pdo_pgsql \
    pdo_mysql \
    pgsql \
    iconv \
    soap \
    ftp

RUN docker-php-ext-enable apcu pdo_pgsql sodium

RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp
RUN docker-php-ext-install -j"$(nproc)" gd
RUN docker-php-ext-enable gd

RUN pecl install mcrypt-1.0.6
RUN docker-php-ext-enable mcrypt

# Install AMQP
RUN apt-get update
RUN apt-get install -y --no-install-recommends librabbitmq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN pecl install amqp
RUN docker-php-ext-enable amqp
RUN docker-php-ext-install sockets

RUN echo 'alias sf="php bin/console"' >> ~/.bashrc

# Install Oh my Zsh
RUN apt-get install -y --no-install-recommends zsh
RUN bash -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
RUN sed -i -- 's/robbyrussell/kafeitu/g' /root/.zshrc # Other awesome theme: random kafeitu sonicradish wezm+
RUN mkdir -p /root/.oh-my-zsh/custom/themes
COPY kafeitu.zsh-theme /root/.oh-my-zsh/custom/themes

# Install Composer
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer
RUN composer self-update 2.5.8

# Add Config
COPY .zshrc /root
COPY vim/.vimrc /root
COPY ssh /root/.ssh
RUN if [ -f ~/.ssh/id_rsa ]; then chmod 600 ~/.ssh/id_rsa; fi
RUN if [ -f ~/.ssh/id_rsa.pub ]; then chmod 600 ~/.ssh/id_rsa.pub; fi
COPY php.ini /usr/local/etc/php/
COPY php-composer.ini /usr/local/etc/php/

# Prevent error in nginx error.log
RUN touch /var/log/xdebug_remote.log
RUN chmod 777 /var/log/xdebug_remote.log

# NodeJS and Packages
ENV NODE_VERSION=16.20.2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

# Symbolic links for NodeJS
RUN ln -s /usr/bin/nodejs /usr/local/bin/node
RUN ln -s /usr/bin/npm /usr/local/bin/npm

ENV NPM_VERSION=9.8.1
RUN npm install -g npm@${NPM_VERSION}

ENV PNPM_VERSION=8.8.0
RUN npm install -g pnpm@${PNPM_VERSION}
RUN pnpm config set store-dir /var/www/shared/.pnpm-store

# Symfony cli
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash
RUN apt-get install -y --no-install-recommends symfony-cli

#ssh2 plugin
RUN apt-get install -y --no-install-recommends libssh2-1-dev libssh2-1 \
    && pecl install ssh2-1.3.1 \
    && docker-php-ext-enable ssh2

# Right access
RUN usermod -u 1000 www-data

# Fix time shift problem
RUN rm /etc/localtime \
    && ln -snf /usr/share/zoneinfo/Europe/Paris /etc/localtime

# Supervisor
#RUN apt-get install -y --no-install-recommends supervisor \
#    && mkdir -p /var/log/supervisord

# Xdebug - disabled by default
ARG XDEBUG_VERSION=3.2.2
RUN set -eux; \
	pecl install xdebug-"$XDEBUG_VERSION"; \
	docker-php-ext-enable xdebug

RUN mkdir /usr/local/etc/php/conf.d.disabled
RUN mv /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini /usr/local/etc/php/conf.d.disabled/docker-php-ext-xdebug.ini
COPY xdebug.ini /usr/local/etc/php/conf.d.disabled/

#CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]