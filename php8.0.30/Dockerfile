# ============================================================
# PHP 8.0.30 + Apache — Imagen de desarrollo local
# LibelulaSoft | libelulasoft/php8030
# ============================================================
# Build (desde raíz del repo):
#   docker build -t libelulasoft/php8030:2.0.0 -t libelulasoft/php8030:2 -f php8.0.30/Dockerfile .
#   docker build --build-arg ENABLE_XDEBUG=false -t libelulasoft/php8030:2-noxdebug -f php8.0.30/Dockerfile .
# Push:
#   docker tag libelulasoft/php8030:2 libelulasoft/php8030:latest
#   docker push libelulasoft/php8030:2.0.0 libelulasoft/php8030:2 libelulasoft/php8030:latest
# ============================================================

# ============================================================
# Stage 1: builder — dev headers + compilación de extensiones
# ============================================================
FROM php:8.0-apache AS builder

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git vim nano bash-completion \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
        libmagickwand-dev libxml2-dev libzip-dev libssl-dev \
        pkg-config build-essential autoconf && \
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

# Instalar /opt/devtools: Codeception 5 + PHPUnit 9 + módulos Yii2
# (isolado del vendor del proyecto consumidor)
COPY php8.0.30/devtools/composer.json /opt/devtools/composer.json
RUN composer install \
    --working-dir=/opt/devtools \
    --no-interaction \
    --prefer-dist \
    --no-progress \
    --optimize-autoloader

# ============================================================
# Stage 2: runtime — imagen final sin dev headers (~120-180 MB menos)
# ============================================================
FROM php:8.0-apache

ARG ENABLE_XDEBUG=true

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Solo runtime libs (sin -dev headers)
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

# Copiar extensiones compiladas y sus inis
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Composer + devtools
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer
COPY --from=builder /opt/devtools /opt/devtools

# Symlinks de test tools en PATH (fallback para proyectos con vendor hardcodeado)
RUN ln -s /opt/devtools/vendor/bin/codecept /usr/local/bin/codecept && \
    ln -s /opt/devtools/vendor/bin/phpunit   /usr/local/bin/phpunit

# Scripts CI/CD en PATH (lint.sh, zip.sh — usados desde bitbucket-pipelines y similares)
COPY cicd/lint.sh cicd/zip.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/lint.sh /usr/local/bin/zip.sh

# mod_rewrite
RUN a2enmod rewrite

# Xdebug 3.x — configurar solo si ENABLE_XDEBUG=true (default)
# Si false: elimina el ini para deshabilitar completamente la extensión
RUN if [ "$ENABLE_XDEBUG" = "true" ]; then \
        printf "xdebug.mode=debug\nxdebug.start_with_request=yes\nxdebug.client_host=host.docker.internal\nxdebug.client_port=9003\nxdebug.log=/var/log/xdebug.log\n" \
            >> /usr/local/etc/php/conf.d/zz-xdebug.ini ; \
    else \
        rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ; \
    fi

# Pre-crear log de Xdebug con owner correcto (www-data no puede escribir en /var/log por defecto)
RUN touch /var/log/xdebug.log && chown www-data:www-data /var/log/xdebug.log

WORKDIR /var/www/html
