FROM php:7.4.6-apache-buster

ENV ACCEPT_EULA "Y"
ENV WEB_ROOT "/var/www/html"
ENV APACHE_RUN_USER "www-data"
ENV APACHE_RUN_GROUP "www-data"
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_PACKAGIST_REPO_URL "https://packagist.co.za"

# Install Debian packages
RUN apt -yqq update \
    && apt install -yqq \
        dos2unix \
        git \
        gnupg2 \
        libc-client-dev \
        libfontconfig1 \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libpng-dev \
        libssl1.1 \
        libxml2-dev \
        libzip-dev \
        unzip \
        vim \
        wget \
    && apt autoremove -y \
    && rm -r /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    bcmath \
    calendar \
    intl \
    opcache \
    pcntl \
    pdo \
    pdo_mysql \
    zip

RUN pecl install \
    apcu \
    ast \
    xdebug-2.9.5

# Enable PHP extensions
RUN docker-php-ext-enable \
    apcu \
    ast \
    xdebug

# Configure PHP extensions
RUN docker-php-ext-configure gd
RUN docker-php-ext-configure intl
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl

RUN docker-php-ext-install \
    gd \
    imap

# Install NPM and Yarn
COPY ./docker/node/node-installer.sh /usr/local/bin/node-installer

RUN chmod +x /usr/local/bin/node-installer \
    && dos2unix /usr/local/bin/node-installer \
    && node-installer \
    && npm --version \
    && yarn --version

# Install Composer
COPY ./docker/php/composer-installer.sh /usr/local/bin/composer-installer

RUN chmod +x /usr/local/bin/composer-installer \
    && dos2unix /usr/local/bin/composer-installer \
    && composer-installer \
    && mv composer.phar /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer \
    && echo "{}" > /root/.composer/composer.json \
    && composer config --global repo.packagist composer ${COMPOSER_PACKAGIST_REPO_URL}

# Copy Apache config and enable URL rewrites
COPY ./docker/apache/vhost.conf /etc/apache2/sites-available/000-default.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && a2enmod rewrite negotiation

# Copy config files
COPY ./docker/php/conf.d/* /usr/local/etc/php/conf.d/
COPY ./docker/php/php.ini /usr/local/etc/php

RUN touch /var/log/xdebug.log \
    && chmod 777 /var/log/xdebug.log

# Copy project files
COPY --chown=${APACHE_RUN_USER}:${APACHE_RUN_GROUP} . ${WEB_ROOT}/

RUN composer dump-autoload

WORKDIR ${WEB_ROOT}

EXPOSE 80
