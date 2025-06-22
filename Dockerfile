FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
    build-base \
    autoconf \
    libzip-dev \
    zip \
    oniguruma-dev \
    postgresql-dev \
    mysql-client \
    git \
    nginx \
    libpng-dev \
    freetype-dev

RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html

EXPOSE 9000

CMD ["php-fpm"]