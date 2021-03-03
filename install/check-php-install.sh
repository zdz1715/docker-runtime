#!/bin/bash

log()
{
  echo "$1：$2"
}

log_error()
{
  log "[ERROR]" "$1"
}

step()
{
  echo
  echo "# ========================================================= #"
  echo "# $1 "
  echo "# ========================================================= #"
}

# 检测是否存在php
step "php版本"
if ! php -v 2> /dev/null ;then
  log_error "请安装php"
  exit 1
fi

PHP_MODULE=$(php -m > /dev/stdout)

step "php扩展"
echo "$PHP_MODULE"

PHP_WARNING=$(php -v 2>/dev/stdout | grep Warning)
PHP_ERROR=$(php -v 2>/dev/stdout | grep Error)
if [[ "$PHP_WARNING" ]] || [[ "$PHP_ERROR" ]] ; then
  step "php报警"
  [[ "$PHP_WARNING" ]] && log_error "$PHP_WARNING"
  [[ "$PHP_ERROR" ]] && log_error "$PHP_ERROR"
  exit 1
fi
