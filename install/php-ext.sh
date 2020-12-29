#!/bin/bash

dockerPHPExtEnable()
{
  iniName="docker-php-ext-$1.ini"
  iniPath="$PHP_ETC_ROOT/mods-available/$iniName"
  echo "extension=$1.so" > "$iniPath"
  ln -s "$iniPath" "$PHP_ETC_ROOT/fpm/conf.d/$iniName"
  ln -s "$iniPath" "$PHP_ETC_ROOT/cli/conf.d/$iniName"
}

installExtensionFromTgz()
{
    tgzName=$1
    extensionName="${tgzName%%-*}"

    mkdir "${extensionName}"
    tar -xf "${tgzName}.tgz" -C "${extensionName}" --strip-components=1
    ( cd "${extensionName}" && phpize && ./configure && make "${MC}" && make install )

    echo "extension=${extensionName}.so" > "${PHP_INI_D}/${extensionName}.ini"
    echo "extension=${extensionName}.so" > "${PHP_CLI_INI_D}/${extensionName}.ini"
    echo "extension=${extensionName}.so" > "${PHP_ETC}/mods-available/${extensionName}.ini"
}



echo
echo "============================================"
echo "PHP version               : ${PHP_VERSION}"
echo "Extra Extensions          : ${PHP_EXTENSIONS}"
echo "Multicore Compilation     : ${MC}"
echo "Work directory            : ${PWD}"
echo "============================================"
echo

build_deps="${PHP_VERSION}-dev"

if [ "${PHP_EXTENSIONS}" != "" ]; then
    echo "---------- Install general dependencies ----------"
    apt-get update
    apt-get install -y ${build_deps}
fi

echo "---------- Install extra dependencies ----------"

if [ -z "${EXTENSIONS##*,amqp,*}" ]; then
    echo "---------- Install amqp ----------"
    apt-get install -y "${PHP_VERSION}-amqp"
fi

if [ -z "${EXTENSIONS##*,bcmath,*}" ]; then
    echo "---------- Install bcmath ----------"
    apt-get install -y "${PHP_VERSION}-bcmath"
fi

if [ -z "${EXTENSIONS##*,curl,*}" ]; then
    echo "---------- Install curl ----------"
    apt-get install -y "${PHP_VERSION}-curl"
fi


if [ -z "${EXTENSIONS##*,gd,*}" ]; then
    echo "---------- Install gd ----------"
    apt-get install -y "${PHP_VERSION}-gd"
fi

if [ -z "${EXTENSIONS##*,mbstring,*}" ]; then
    echo "---------- Install mbstring ----------"
    apt-get install -y "${PHP_VERSION}-mbstring"
fi

if [ -z "${EXTENSIONS##*,mongodb,*}" ]; then
    echo "---------- Install mongodb ----------"
    installExtensionFromTgz mongodb-1.8.2
fi

if [ -z "${EXTENSIONS##*,pdo_mysql,*}" ]; then
    echo "---------- Install mysql ----------"
    apt-get install -y "${PHP_VERSION}-mysql"
fi


if [ -z "${EXTENSIONS##*,redis,*}" ]; then
    echo "---------- Install redis ----------"
    apt-get install -y "${PHP_VERSION}-redis"
fi

if [ -z "${EXTENSIONS##*,soap,*}" ]; then
    echo "---------- Install soap ----------"
    apt-get install -y "${PHP_VERSION}-soap"
fi

if [ -z "${EXTENSIONS##*,xml,*}" ]; then
    echo "---------- Install xmlrpc ----------"
    apt-get install -y "${PHP_VERSION}-xml"
fi

if [ -z "${EXTENSIONS##*,xmlrpc,*}" ]; then
    echo "---------- Install xmlrpc ----------"
    apt-get install -y "${PHP_VERSION}-xmlrpc"
fi

if [ -z "${EXTENSIONS##*,zip,*}" ]; then
    echo "---------- Install zip ----------"
    apt-get install -y "${PHP_VERSION}-zip"
fi



if [ -z "${EXTENSIONS##*,rdkafka,*}" ]; then
    echo "---------- Install rdkafka ----------"
    installExtensionFromTgz rdkafka-4.0.3
fi

if [ -z "${EXTENSIONS##*,swoole,*}" ]; then
    echo "---------- Install swoole ----------"
    installExtensionFromTgz swoole-4.5.2
fi


if [ -z "${EXTENSIONS##*,xdebug,*}" ]; then
    echo "---------- Install xdebug ----------"
    installExtensionFromTgz xdebug-2.9.6
fi



echo "---------- Install Complete ---------"

if [ "${PHP_EXTENSIONS}" != "" ]; then
    echo "---------- Del  build-deps ----------"
    apt-get --purge -y remove ${build_deps}
    apt-get -y autoremove
    apt-get -y clean
    rm -rf /var/lib/apt/lists/*;
fi






