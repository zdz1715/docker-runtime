#!/bin/bash


#NGINX_HEADERS=${NGINX_HEADERS:()}


nginx_add_header()
{
  echo "add_header $1 $2 always;";
  return 0
}

COMMAND() {
  echo "[$(date +%H:%M:%S)] [COMMAND] $*"
}

INFO() {
  echo "[$(date +%H:%M:%S)] [INFO] $*"
}

cron_format() {
  mapfile -t file_list < <(find "$1" -type f)
  for f in "${file_list[@]}"
  do
    dos2unix "$f"
    # 插入新行
    echo '' >> "$f"
  done
}

if [ -n "${UPLOAD_LIMIT}" ]; then
  echo "client_max_body_size $UPLOAD_LIMIT;" > "${NGINX_CONF_D}/upload-limit.conf"
  {
    echo "upload_max_filesize = $UPLOAD_LIMIT";
    echo "post_max_size = $UPLOAD_LIMIT";
  } > "${PHP_INI_D}/upload-limit.ini"
fi

pm_min_spare_servers=${MIN_SPARE_SERVERS:-16}
pm_max_spare_servers=${MAX_SPARE_SERVERS:-16}

{
  echo "pm.max_children = $(( pm_min_spare_servers+pm_max_spare_servers))";
  echo "pm.min_spare_servers = $pm_min_spare_servers";
  echo "pm.max_spare_servers = $pm_max_spare_servers";
  echo "pm.start_servers = $(( (pm_min_spare_servers+pm_max_spare_servers)/2 ))";
} >> "${PHP_FPM_POOL_CONF}"

# 创建日志目录
! [ -d "$SUPERVISOR_LOG_DIR" ] && mkdir "$SUPERVISOR_LOG_DIR"
! [ -d "/usr/run" ] && mkdir "/usr/run"


if [ "$CRON_LARAVEL_SCHEDULE" != false ]; then
  {
    echo "* * * * * root /usr/local/bin/cron-log -u www-data /usr/bin/php /var/www/artisan schedule:run"
  } > "${CRON_D}/laravel-schedule"
fi

EXEC_CMD=0

# 循环参数执行
for i in "$@"
do

COMMAND "$i"

#cron
if [ "$i" = 'cron' ]; then

# 格式化文件
cron_format "${CRON_D}"


cat > "${SUPERVISOR_CONF_DIR}/${i}.ini" <<EOF
[program:${i}]
user=root
command=cron -f
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=${SUPERVISOR_LOG_DIR}/${i}.log
EOF

elif [ "$i" = 'laravel-queue' ]; then

cat > "${SUPERVISOR_CONF_DIR}/${i}.ini" <<EOF
[program:${i}]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/artisan queue:work --sleep=3 --tries=3
user=www-data
autostart=true
autorestart=true
numprocs=8
redirect_stderr=true
stdout_logfile=${SUPERVISOR_LOG_DIR}/${i}.log
EOF

elif [ "$i" = 'laravel-socket' ]; then

cat > "${SUPERVISOR_CONF_DIR}/${i}.ini" <<EOF
[program:${i}]
command=php /var/www/artisan socket start
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=${SUPERVISOR_LOG_DIR}/${i}.log
EOF

elif [ "$i" = 'sh' ] || [ "$i" = '/bin/bash' ] || [ "$i" = 'bash' ]; then
  EXEC_CMD=1
else
  # 挂起运行，防止阻塞下面主要进程
  nohup /bin/bash -c "$i" >/dev/stdout 2>&1 &
fi

done

# 只执行命令行
if [ "$EXEC_CMD" = 1 ]; then
  exec "/bin/bash"
  exit 0
fi

# 修改nginx的权限
chown -R www-data:www-data /var/lib/nginx

# 生成nginx的默认配置
if [ -n "${NGINX_HEADER_ALLOW_ORIGIN}" ]; then
  NGINX_HEADER_ALLOW_ORIGIN_STR=$(nginx_add_header "Access-Control-Allow-Origin" "$NGINX_HEADER_ALLOW_ORIGIN")
fi

if [ -n "${NGINX_HEADER_ALLOW_HEADERS}" ]; then
  NGINX_HEADER_AllOW_HEADERS_STR=$(nginx_add_header "Access-Control-Allow-Headers" "$NGINX_HEADER_ALLOW_HEADERS")
fi

if [ "$NGINX_OPTIONS_RETURN" != false ]; then
  NGINX_OPTIONS_RETURN_STR="if (\$request_method = 'OPTIONS' ) { return 200; }"
fi





if [ ! -f "$NGINX_DEFAULT_CONF" ]; then

cat > "$NGINX_DEFAULT_CONF" <<EOF
server {
    listen 80 default_server;
#    listen [::]:80 default_server;

    server_name _;
    root /var/www/public;

    index index.php;
    charset utf-8;

    $NGINX_HEADER_ALLOW_ORIGIN_STR
    $NGINX_HEADER_AllOW_HEADERS_STR

    location / {
        $NGINX_OPTIONS_RETURN_STR
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi.conf;
        fastcgi_pass $PHP_FPM_SOCK;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF
else
  # 转换php-fpm
  sed -i "s~\$PHP_FPM_SOCK~$PHP_FPM_SOCK~g" "$NGINX_DEFAULT_CONF"
fi

  INFO "$NGINX_DEFAULT_CONF"
  cat "$NGINX_DEFAULT_CONF"

# 兼容以前的ini文件
echo "files = /etc/supervisor/conf.d/*.ini" >> /etc/supervisor/supervisord.conf

# 使用守护程序运行程序 /etc/supervisor.d/init.ini
supervisord -n -c /etc/supervisor/supervisord.conf