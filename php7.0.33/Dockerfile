# ============================================================
# PHP 7.0.33 + Apache — Imagen de desarrollo local
# LibelulaSoft | libelulasoft/php7033
# ============================================================
# Build (desde raíz del repo):
#   docker build -t libelulasoft/php7033:2.0.0 -t libelulasoft/php7033:2 -f php7.0.33/Dockerfile .
#   docker build --build-arg ENABLE_XDEBUG=false -t libelulasoft/php7033:2-noxdebug -f php7.0.33/Dockerfile .
# Push:
#   docker tag libelulasoft/php7033:2 libelulasoft/php7033:latest
#   docker push libelulasoft/php7033:2.0.0 libelulasoft/php7033:2 libelulasoft/php7033:latest
# ============================================================

# ============================================================
# Stage 1: builder — dev headers + compilación de extensiones
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

# Instalar /opt/devtools: Codeception 4.1 + PHPUnit 6.5 + módulos Yii2
# (isolado del vendor del proyecto consumidor)
COPY php7.0.33/devtools/composer.json /opt/devtools/composer.json
RUN composer install \
    --working-dir=/opt/devtools \
    --no-interaction \
    --prefer-dist \
    --no-progress \
    --ignore-platform-reqs \
    --optimize-autoloader

# ============================================================
# Stage 2: runtime — imagen final sin dev headers (~150-200 MB menos)
# ============================================================
FROM php:7.0-apache

ARG ENABLE_XDEBUG=true

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# Repositorios archivados + solo runtime libs
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

# Xdebug 2.x — configurar solo si ENABLE_XDEBUG=true (default)
# Si false: elimina el ini para deshabilitar completamente la extensión
RUN if [ "$ENABLE_XDEBUG" = "true" ]; then \
        printf "xdebug.remote_enable=1\nxdebug.remote_autostart=1\nxdebug.remote_host=host.docker.internal\nxdebug.remote_port=9000\nxdebug.remote_log=/var/log/xdebug.log\n" \
            >> /usr/local/etc/php/conf.d/zz-xdebug.ini ; \
    else \
        rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ; \
    fi

# Pre-crear log de Xdebug con owner correcto (www-data no puede escribir en /var/log por defecto)
RUN touch /var/log/xdebug.log && chown www-data:www-data /var/log/xdebug.log

WORKDIR /var/www/html
