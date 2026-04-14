FROM php:7.0-apache

# Configurar repositorios antiguos y herramientas necesarias
RUN echo 'deb http://archive.debian.org/debian stretch main' > /etc/apt/sources.list && \
    echo 'deb http://archive.debian.org/debian-security stretch/updates main' >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/99allow-unauth && \
    apt-get update && \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libmagickwand-dev \
        libxml2-dev \
        libzip-dev \
        libssl-dev \
        unzip \
        git \
        curl \
        pkg-config \
        build-essential && \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
    docker-php-ext-install -j$(nproc) gd soap zip bcmath && \
    pecl install mongodb-1.9.2 imagick xdebug-2.7.2 && \
    docker-php-ext-enable mongodb imagick xdebug && \
    apt-get purge -y --auto-remove \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libmagickwand-dev \
        libxml2-dev \
        libzip-dev \
        libssl-dev \
        pkg-config \
        build-essential && \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
        libmagickwand-6.q16-3 \
        libmagickcore-6.q16-3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Instalar Composer 2
RUN curl -sS https://getcomposer.org/installer | php -- --2 && \
    mv composer.phar /usr/local/bin/composer

# Configurar Xdebug (sin usar `find`)
RUN echo "xdebug.remote_enable=1" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.remote_autostart=1" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.remote_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.remote_port=9000" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.remote_log=/var/log/xdebug.log" >> /usr/local/etc/php/conf.d/xdebug.ini

# Habilitar mod_rewrite de Apache
RUN a2enmod rewrite

# Directorio de trabajo
WORKDIR /var/www/html

# docker build -t libelulasoft/php7033:1.1 .

# docker tag libelulasoft/php7033:1.1 libelulasoft/php7033:latest

# docker push libelulasoft/php7033:latest