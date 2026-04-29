# ============================================================
# PHP 7.0.33 + Apache — Imágenes DEV y PROD
# LibelulaSoft | libelulasoft/php7033-dev | libelulasoft/php7033-prod
# ============================================================
# Build (desde raíz del repo):
#
#   # Imagen DEV (local + Bitbucket Pipelines)
#   docker build --target dev \
#       -t libelulasoft/php7033-dev:2.1.0 \
#       -t libelulasoft/php7033-dev:2 \
#       -t libelulasoft/php7033-dev:latest \
#       -f php7.0.33/Dockerfile .
#
#   # Imagen PROD (ECS / runtime alta carga)
#   docker build --target prod \
#       -t libelulasoft/php7033-prod:2.1.0 \
#       -t libelulasoft/php7033-prod:2 \
#       -t libelulasoft/php7033-prod:latest \
#       -f php7.0.33/Dockerfile .
#
# Diferencias DEV vs PROD:
#
#   | Aspecto             | DEV                          | PROD                   |
#   |---------------------|------------------------------|------------------------|
#   | Xdebug              | ✓ (configurable)             | ✗                      |
#   | /opt/devtools       | full (require + require-dev) | trimmed (--no-dev)     |
#   | phpunit (CLI)       | ✓ symlink en /usr/local/bin  | ✗                      |
#   | sync-dependencies.sh| ✓                            | ✗                      |
#   | lint.sh, zip.sh     | ✓                            | ✗                      |
#   | OPcache tuneado     | default                      | ✓ alta carga           |
#   | display_errors      | default                      | 0 (logs a stderr)      |
#   | Apache logs         | default                      | a stdout/stderr        |
#
# Ambas imágenes traen auto_prepend_file → /opt/devtools/vendor/autoload.php
# para que proyectos legacy con vendor hardcodeado puedan usar libs runtime
# (phpdotenv) sin tocar su composer.
# ============================================================


# ============================================================
# Stage 1: builder — extensiones nativas + dependencias composer
# Capa cara compartida entre DEV y PROD (cacheada).
# ============================================================
FROM php:7.0-apache AS builder

# Repositorios de Debian Stretch archivados (EOL)
RUN echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list && \
    echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update -o APT::Get::AllowUnauthenticated=true && \
    apt-get install -y -o APT::Get::AllowUnauthenticated=true --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libmagickwand-dev \
        libxml2-dev \
        libzip-dev \
        libssl-dev \
        pkg-config \
        build-essential \
        autoconf && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install -j$(nproc) gd soap zip bcmath && \
    pecl install mongodb-1.9.2 imagick-3.4.4 xdebug-2.7.2 && \
    docker-php-ext-enable mongodb imagick xdebug && \
    pecl clear-cache && \
    rm -rf /tmp/pear /tmp/* /var/tmp/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99no-check-valid-until

# Composer 2.2 — último LTS con soporte PHP 7.0
COPY --from=composer:2.2 /usr/bin/composer /usr/local/bin/composer

# Devtools FULL (require + require-dev) — para imagen DEV
COPY php7.0.33/devtools/composer.json /opt/devtools/composer.json
RUN composer install \
    --working-dir=/opt/devtools \
    --no-interaction \
    --prefer-dist \
    --no-progress \
    --ignore-platform-reqs \
    --optimize-autoloader

# Devtools TRIMMED (solo require) — para imagen PROD
RUN mkdir -p /opt/devtools-prod && \
    cp /opt/devtools/composer.json /opt/devtools-prod/composer.json && \
    cp /opt/devtools/composer.lock /opt/devtools-prod/composer.lock && \
    composer install \
        --working-dir=/opt/devtools-prod \
        --no-dev \
        --no-interaction \
        --prefer-dist \
        --no-progress \
        --ignore-platform-reqs \
        --optimize-autoloader


# ============================================================
# Stage 2: dev — desarrollo local + Bitbucket Pipelines
# ============================================================
FROM php:7.0-apache AS dev

ARG ENABLE_XDEBUG=true

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Repos archivados + runtime libs (incluye git/zip/unzip para CI)
RUN echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list && \
    echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update -o APT::Get::AllowUnauthenticated=true && \
    apt-get install -y -o APT::Get::AllowUnauthenticated=true --no-install-recommends \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
        libmagickwand-6.q16-3 \
        libmagickcore-6.q16-3 \
        libzip4 \
        libxml2 \
        ca-certificates \
        unzip \
        zip \
        git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99no-check-valid-until

# Extensiones (incluyendo xdebug)
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Composer + devtools FULL
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer
COPY --from=builder /opt/devtools /opt/devtools

# Symlink phpunit (require-dev) — fallback para proyectos con vendor hardcodeado
# Codeception NO se incluye en PHP 7.0 — nullable types incompatibles con 7.0.33.
RUN ln -s /opt/devtools/vendor/bin/phpunit /usr/local/bin/phpunit

# Auto_prepend de devtools — permite "use Foo\Bar" sin tocar composer del proyecto
RUN echo 'auto_prepend_file=/opt/devtools/vendor/autoload.php' \
    > /usr/local/etc/php/conf.d/zz-devtools-autoload.ini

# Scripts CI/CD (lint.sh, zip.sh) + sync de devtools al host (sync-dependencies.sh)
COPY cicd/lint.sh cicd/zip.sh cicd/sync-dependencies.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/lint.sh /usr/local/bin/zip.sh /usr/local/bin/sync-dependencies.sh

# Apache mod_rewrite
RUN a2enmod rewrite

# Xdebug condicional (true por default en dev)
RUN if [ "$ENABLE_XDEBUG" = "true" ]; then \
        printf "xdebug.remote_enable=1\nxdebug.remote_autostart=1\nxdebug.remote_host=host.docker.internal\nxdebug.remote_port=9000\nxdebug.remote_log=/var/log/xdebug.log\n" \
            >> /usr/local/etc/php/conf.d/zz-xdebug.ini ; \
    else \
        rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ; \
    fi

# Pre-crear log de Xdebug (www-data no escribe en /var/log por defecto)
RUN touch /var/log/xdebug.log && chown www-data:www-data /var/log/xdebug.log

WORKDIR /var/www/html


# ============================================================
# Stage 3: prod — runtime ECS, alta carga, mínimo
# ============================================================
FROM php:7.0-apache AS prod

# Repos archivados + SOLO runtime libs (sin git/unzip/zip — minimal surface)
RUN echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list && \
    echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update -o APT::Get::AllowUnauthenticated=true && \
    apt-get install -y -o APT::Get::AllowUnauthenticated=true --no-install-recommends \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
        libmagickwand-6.q16-3 \
        libmagickcore-6.q16-3 \
        libzip4 \
        libxml2 \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /etc/apt/apt.conf.d/99no-check-valid-until

# Extensiones (sin xdebug — eliminamos el .ini para deshabilitarlo)
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Devtools TRIMMED (solo require: phpdotenv) — disponible en /opt/devtools/vendor
# para legacy projects con vendor hardcodeado que necesiten libs runtime.
COPY --from=builder /opt/devtools-prod /opt/devtools

# Auto_prepend para que proyectos legacy usen libs (phpdotenv) sin tocar su vendor
RUN echo 'auto_prepend_file=/opt/devtools/vendor/autoload.php' \
    > /usr/local/etc/php/conf.d/zz-devtools-autoload.ini

# Habilitar extensión OPcache (viene compilada en php:7.0-apache pero deshabilitada)
RUN docker-php-ext-enable opcache

# OPcache tuneado para alta carga (validate_timestamps=0 — código no cambia en runtime)
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=0'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
} > /usr/local/etc/php/conf.d/zz-opcache-prod.ini

# PHP errors: log a stderr, sin display, sin expose_php
RUN { \
    echo 'display_errors=0'; \
    echo 'display_startup_errors=0'; \
    echo 'log_errors=1'; \
    echo 'error_log=/dev/stderr'; \
    echo 'error_reporting=E_ALL & ~E_DEPRECATED & ~E_STRICT'; \
    echo 'expose_php=0'; \
} > /usr/local/etc/php/conf.d/zz-errors-prod.ini

# Apache: logs a stdout/stderr (ECS/CloudWatch los captura) + mod_rewrite + headers
RUN sed -i \
        -e 's|ErrorLog .*|ErrorLog /dev/stderr|g' \
        -e 's|CustomLog .*|CustomLog /dev/stdout combined|g' \
        /etc/apache2/apache2.conf && \
    a2enmod rewrite headers

# Endurecer ServerTokens / ServerSignature
RUN { \
    echo 'ServerTokens Prod'; \
    echo 'ServerSignature Off'; \
    echo 'TraceEnable Off'; \
} >> /etc/apache2/apache2.conf

WORKDIR /var/www/html
