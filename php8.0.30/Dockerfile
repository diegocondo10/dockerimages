# ============================================================
# PHP 8.0.30 + Apache — Imágenes DEV y PROD
# LibelulaSoft | libelulasoft/php8030-dev | libelulasoft/php8030-prod
# ============================================================
# Build (desde raíz del repo):
#
#   # Imagen DEV (local + Bitbucket Pipelines)
#   docker build --target dev \
#       -t libelulasoft/php8030-dev:2.1.0 \
#       -t libelulasoft/php8030-dev:2 \
#       -t libelulasoft/php8030-dev:latest \
#       -f php8.0.30/Dockerfile .
#
#   # Imagen PROD (ECS / runtime alta carga)
#   docker build --target prod \
#       -t libelulasoft/php8030-prod:2.1.0 \
#       -t libelulasoft/php8030-prod:2 \
#       -t libelulasoft/php8030-prod:latest \
#       -f php8.0.30/Dockerfile .
#
# Diferencias DEV vs PROD:
#
#   | Aspecto             | DEV                          | PROD                   |
#   |---------------------|------------------------------|------------------------|
#   | Xdebug 3            | ✓ (ENABLE_XDEBUG=true)       | ✗                      |
#   | /opt/devtools       | full (require + require-dev) | trimmed (--no-dev)     |
#   | phpunit, codecept   | ✓ symlinks en /usr/local/bin | ✗                      |
#   | sync-dependencies.sh| ✓                            | ✗                      |
#   | lint.sh, zip.sh     | ✓                            | ✗                      |
#   | OPcache tuneado     | default                      | ✓ alta carga           |
#   | display_errors      | default                      | 0 (logs a stderr)      |
#   | Apache logs         | default                      | a stdout/stderr        |
#   | HEALTHCHECK         | -                            | ✓                      |
#
# Ambas imágenes traen auto_prepend_file → /opt/devtools/vendor/autoload.php
# para que proyectos legacy con vendor hardcodeado puedan usar libs runtime
# (phpdotenv) sin tocar su composer.
#
# Findings de auditoría aplicados desde el inicio (vs php7.0.33):
#   - HEALTHCHECK con TCP check vía PHP CLI
#   - Apache logs vía symlinks /dev/stderr (no sed sobre apache2.conf)
#   - composer.lock copiado al builder para reproducibilidad
# ============================================================


# ============================================================
# Stage 1: builder — extensiones nativas + dependencias composer
# Capa cara compartida entre DEV y PROD (cacheada).
# ============================================================
FROM php:8.0-apache AS builder

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
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
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) gd soap zip bcmath && \
    pecl install imagick-3.7.0 xdebug-3.1.6 mongodb-1.11.0 && \
    docker-php-ext-enable imagick xdebug mongodb && \
    pecl clear-cache && \
    rm -rf /tmp/pear /tmp/* /var/tmp/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Composer 2.7 pinneado
COPY --from=composer:2.7 /usr/bin/composer /usr/local/bin/composer

# Devtools FULL (require + require-dev) — para imagen DEV
# Si existe composer.lock, se usa para reproducibilidad bit-a-bit
COPY php8.0.30/devtools/composer.json /opt/devtools/composer.json
COPY php8.0.30/devtools/composer.loc[k] /opt/devtools/
RUN composer install \
    --working-dir=/opt/devtools \
    --no-interaction \
    --prefer-dist \
    --no-progress \
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
        --optimize-autoloader


# ============================================================
# Stage 2: dev — desarrollo local + Bitbucket Pipelines
# ============================================================
FROM php:8.0-apache AS dev

ARG ENABLE_XDEBUG=true

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Runtime libs + utilidades de dev (git, vim, etc.)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git vim nano bash-completion \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
        libmagickwand-6.q16-6 \
        libmagickcore-6.q16-6 \
        libzip4 \
        libxml2 \
        libssl1.1 \
        ca-certificates \
        unzip \
        zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Extensiones (incluyendo xdebug)
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Composer + devtools FULL
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer
COPY --from=builder /opt/devtools /opt/devtools

# Symlinks de testing (require-dev) — fallback para proyectos con vendor hardcodeado
RUN ln -s /opt/devtools/vendor/bin/codecept /usr/local/bin/codecept && \
    ln -s /opt/devtools/vendor/bin/phpunit  /usr/local/bin/phpunit

# Auto_prepend de devtools — permite "use Foo\Bar" sin tocar composer del proyecto
RUN echo 'auto_prepend_file=/opt/devtools/vendor/autoload.php' \
    > /usr/local/etc/php/conf.d/zz-devtools-autoload.ini

# Scripts CI/CD
COPY cicd/lint.sh cicd/zip.sh cicd/sync-dependencies.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/lint.sh /usr/local/bin/zip.sh /usr/local/bin/sync-dependencies.sh

# Apache mod_rewrite + headers
RUN a2enmod rewrite headers

# Xdebug 3 condicional (true por default en dev)
RUN if [ "$ENABLE_XDEBUG" = "true" ]; then \
        printf "xdebug.mode=debug\nxdebug.start_with_request=yes\nxdebug.client_host=host.docker.internal\nxdebug.client_port=9003\nxdebug.log=/var/log/xdebug.log\n" \
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
FROM php:8.0-apache AS prod

# SOLO runtime libs (sin git/unzip/zip/dev tools — minimal surface)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
        libmagickwand-6.q16-6 \
        libmagickcore-6.q16-6 \
        libzip4 \
        libxml2 \
        libssl1.1 \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Extensiones (sin xdebug — eliminamos el .ini para deshabilitarlo)
# NOTA: si en el futuro agregás otra extensión que no quieras en prod,
# acordate de eliminarla acá también.
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Devtools TRIMMED (solo require: phpdotenv) — disponible en /opt/devtools/vendor
# para legacy projects que necesiten libs runtime sin tocar su composer.
COPY --from=builder /opt/devtools-prod /opt/devtools

# Auto_prepend para que proyectos legacy usen libs (phpdotenv) sin tocar su vendor
RUN echo 'auto_prepend_file=/opt/devtools/vendor/autoload.php' \
    > /usr/local/etc/php/conf.d/zz-devtools-autoload.ini

# Habilitar extensión OPcache (viene compilada en php:8.0-apache pero deshabilitada)
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

# Apache: logs a stdout/stderr via symlinks (más robusto que sed sobre apache2.conf)
# + mod_rewrite + headers
RUN ln -sf /dev/stderr /var/log/apache2/error.log && \
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stdout /var/log/apache2/other_vhosts_access.log && \
    a2enmod rewrite headers

# Endurecer ServerTokens / ServerSignature
RUN { \
    echo 'ServerTokens Prod'; \
    echo 'ServerSignature Off'; \
    echo 'TraceEnable Off'; \
} >> /etc/apache2/apache2.conf

WORKDIR /var/www/html

# Healthcheck — TCP check al puerto 80 vía PHP CLI (sin curl, sin bash)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD php -r "exit(@stream_socket_client('tcp://127.0.0.1:80', \$e, \$es, 1) ? 0 : 1);"
