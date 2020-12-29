# 初始化镜像
FROM ubuntu:20.04

COPY etc/apt/sources.list /etc/apt/sources.list


## 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    apt-get -y update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        nginx \
        ca-certificates \
        php7.4-fpm \
        supervisor \
        cron \
        curl \
    ; \
    curl -k -o /usr/bin/composer https://mirrors.aliyun.com/composer/composer.phar; \
    chmod +x /usr/bin/composer; \
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/; \
    rm -rf /var/lib/apt/lists/*;


#################################### 内置扩展 ################################################
## calendar,Core,ctype,date,exif,FFI,fileinfo,filter,ftp,gettext,hash,iconv,json,libxml,
## openssl,pcntl,pcre,PDO,Phar,posix,readline,Reflection,session,shmop,sockets,sodium,SPL,
## standard,sysvmsg,sysvsem,sysvshm,tokenizer,xsl,Zend OPcache,zlib
#################################### 可选 ###################################################
## amqp,bcmath,curl,gd,mbstring,mongodb,pdo_mysql,redis,soap,xml,xmlrpc,zip

ARG PHP_EXTENSIONS=amqp,bcmath,curl,gd,mbstring,mongodb,pdo_mysql,redis,soap,xml,xmlrpc,zip


ENV PHP_VERSION="php7.4"
ENV PHP_ETC="/etc/php/7.4"
ENV EXTENSIONS=",${PHP_EXTENSIONS},"
ENV PHP_INI_D="${PHP_ETC}/fpm/conf.d"
ENV PHP_CLI_INI_D="${PHP_ETC}/cli/conf.d"
ENV PHP_FPM_CONF_D="${PHP_ETC}/fpm/pool.d"
ENV PHP_FPM_POOL_CONF="${PHP_ETC}/fpm/pool.d/www.conf"
ENV PHP_FPM_SOCK="unix:/usr/run/php-fpm.sock"


ENV NGINX_CONF_D="/etc/nginx/conf.d"
ENV NGINX_DEFAULT_CONF="$NGINX_CONF_D/default.conf"
ENV NGINX_OPTIONS_RETURN=true

ENV SUPERVISOR_CONF_DIR='/etc/supervisor/conf.d'
ENV SUPERVISOR_LOG_DIR='/var/log/supervisor'

ENV CRON_D='/etc/cron.d'
ENV CRON_LARAVEL_SCHEDULE=true




## 拷贝配置文件
COPY etc /etc/
COPY entrypoint.sh /entrypoint.sh

## 拷贝脚本
COPY ./bin /usr/local/bin

## 安装php扩展
COPY install /tmp/custom-install
WORKDIR /tmp/custom-install


RUN apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests dos2unix; \
    dos2unix php-ext.sh /entrypoint.sh /usr/local/bin/*; \
    chmod +x php-ext.sh /entrypoint.sh; \
    chmod a+x /usr/local/bin/*; \
    export MC="-j$(nproc)"; \
    /bin/bash php-ext.sh; \
    rm -rf /tmp/custom-install "$NGINX_DEFAULT_CONF" /var/lib/apt/lists/*;


EXPOSE 80

WORKDIR /var/www

ENTRYPOINT ["/entrypoint.sh"]
