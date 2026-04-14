FROM php:8.0-apache

ARG ENABLE_XDEBUG=true

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer

# Instalación de paquetes y extensiones
RUN apt-get update && apt-get install -y --no-install-recommends \
    git vim nano bash-completion \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    libmagickwand-dev libxml2-dev libzip-dev libssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd soap zip bcmath \
    && pecl install imagick xdebug mongodb-1.11.0 \
    && docker-php-ext-enable imagick xdebug mongodb \
    && rm -rf /var/lib/apt/lists/*

# Configurar Xdebug opcionalmente
RUN if [ "$ENABLE_XDEBUG" = "true" ]; then \
    echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.log=/var/log/xdebug.log" >> /usr/local/etc/php/conf.d/xdebug.ini ; \
fi


# Habilitar mod_rewrite
RUN a2enmod rewrite

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Directorio de trabajo
WORKDIR /var/www/html


#docker build -t libelulasoft/php8030:1 .

#docker tag libelulasoft/php8030:1 libelulasoft/php8030:latest
#docker push libelulasoft/php8030:latest