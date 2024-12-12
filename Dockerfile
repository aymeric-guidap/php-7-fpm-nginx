FROM php:8.2-fpm-bullseye

ARG LOG_STREAM=/var/stdout
ENV TERM=xterm

# Update and install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagickwand-dev \
    libmagickcore-dev \
    libcurl4-gnutls-dev \
    zlib1g-dev \
    libicu-dev \
    supervisor \
    git \
    curl \
    ssh \
    rsync \
    make \
    awscli \
    libzip-dev \
    pngquant \
    jpegoptim \
    gnupg \
    dirmngr \
    wget \
    unzip

# Install fonts and wkhtmltopdf
RUN apt-get install -y --no-install-recommends \
    libfontenc1 \
    xfonts-75dpi \
    xfonts-base \
    xfonts-encodings \
    xfonts-utils \
    wkhtmltopdf \
    libonig-dev \
    nginx

# Install PHP extensions
RUN pecl install imagick xdebug && \
    docker-php-ext-enable imagick xdebug

# Install core PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    intl \
    bcmath \
    mbstring \
    zip \
    sockets \
    gd \
    opcache

RUN if [ "$(uname -m)" = "aarch64" ]; then \
    echo "deb [arch=arm64] http://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list; \
    else \
    echo "deb http://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list; \
    fi \
    && wget -qO - http://nginx.org/keys/nginx_signing.key | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y nginx

# Cleanup to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker/php.ini /usr/local/etc/php/

RUN curl -sL https://deb.nodesource.com/setup_14.x | sed -e "s/sleep /echo /g" | bash \
    && apt-get install -y nodejs

RUN npm install -g yarn \
    && npm install -g gulp \
    && npm rebuild node-sass

# Composer (use a stable v2.x version)
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.2.0 \
    && rm -rf /tmp/* /var/tmp/*

# Forward Nginx logs to Docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Timezone and permissions
RUN unlink /etc/localtime \
    && ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    && chmod -R g+rwx /var/www/html \
    && umask 0007

EXPOSE 80 443

RUN ln -sf /dev/stdout /var/stdout \
    && ln -sf /dev/stderr /var/stderr

ADD docker/start.sh /start.sh
RUN chmod +x /start.sh

ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait
RUN chmod +x /wait

CMD /wait && /start.sh
