# php运行环境镜像
基于ubuntu20.04、php7.4、nginx1.18、supervisor4.1

>### 使用方式
#### 构建
复制`Dockerfile.example`到项目中，重命令为`Dockerfile`，然后`docker build`

**ps：下面都是以你构建好的项目容器为视角说明**
#### 进入容器
`/bin/bash`
#### 包管理器(已使用阿里云镜像源)
注意：安装别的包之前需要先`apt update`
```bash
apt search vim
apt install vim
apt remove vim
``` 

>### 内置环境变量
#### php
| 变量名称 | 描述 | 默认值 |
| :---- | :---- | :---- |
| PHP_VERSION | php版本 | `php7.4` |
| PHP_ETC | php配置文件所在的etc目录 | `/usr/local/etc` |
| EXTENSIONS | php安装的自定义扩展 | `,amqp,bcmath,gd,mongodb,mysqli,pcntl,pdo_mysql,redis,soap,xmlrpc,zip,` |
| PHP_INI_D | php ini配置文件目录 | `/etc/php/7.4/fpm/conf.d` |
| PHP_CLI_INI_D | php ini配置文件目录 | `/etc/php/7.4/cli/conf.d` |
| PHP_FPM_CONF_D | php-fpm配置文件目录 | `/etc/php/7.4/fpm/pool.d` |
| PHP_FPM_POOL_CONF | php-fpm项目配置文件 | `/etc/php/7.4/fpm/pool.d/www.conf` |
| PHP_FPM_SOCK | php-fpm进程sock文件 | `unix:/run/php/php7.4-fpm.sock` |

#### nginx
| 变量名称 | 描述 | 默认值 |
| :---- | :---- | :---- |
| NGINX_CONF_D | nginx的conf.d目录 | `/etc/nginx/conf.d` |
| NGINX_DEFAULT_CONF | nginx项目默认配置文件，**可覆盖此配置文件达到自定义设置** | `/etc/nginx/conf.d/default.conf` |
| NGINX_OPTIONS_RETURN | 当为true时，会配置`if ($request_method = 'OPTIONS' ) { return 200; }`, false不处理 | `true` |
| NGINX_HEADER_ALLOW_ORIGIN | `Access-Control-Allow-Origin`的值，推荐`*` | - |
| NGINX_HEADER_ALLOW_ORIGIN | `Access-Control-Allow-Headers`的值，推荐`*,...`，低版本浏览器可能`*`不生效，所以还需明确列出 | - |

#### supervisor
| 变量名称 | 描述 | 默认值 |
| :---- | :---- | :---- |
| SUPERVISOR_CONF_DIR | 配置目录 | `/etc/supervisor/conf.d` |
| SUPERVISOR_LOG_DIR | 日志目录 | `/var/log/supervisor` |

#### cron
| 变量名称 | 描述 | 默认值 |
| :---- | :---- | :---- |
| CRON_D | 定时任务配置目录 | `/etc/cron.d` |
| CRON_LARAVEL_SCHEDULE | 添加laravel调度定时任务 | `true` |

#### 额外变量
| 变量名称 | 描述 | 默认值 |
| :---- | :---- | :---- |
| UPLOAD_LIMIT | 上传文件大小，会同时设置php-fpm的upload_max_filesize、post_max_size和nginx的client_max_body_size | - |
| MIN_SPARE_SERVERS | 对应pm.max_spare_servers | 16 |
| MAX_SPARE_SERVERS | 对应pm.max_spare_servers | 16 |

>### 镜像内包含软件
- nginx：80 端口http，指向/var/www/public
- php7.4-fpm，包含laravel所需的基本扩展,若需要别的扩展请在项目Dockerfile里单独安装
- supervisor：主程序，默认启动，用于管理和运行`php-fpm`,`nginx`,`cron`
- cron：默认未启动，已配置好laravel任务调度的运行

#### 管理软件
```bash
# 状态
supervisorctl status

# 重启
supervisorctl restart php-fpm

# 停止
supervisorctl stop php-fpm

# 重新加载配置
supervisorctl reload
```

>### 内置命令
```dockerfile
## 默认以root用户运行，若想以www-data运行，则写成这样：[ "su - www-data -s /bin/bash -c '$otherCommand'" ]
CMD ["cron", "laravel-queue", "$otherCommand", "..."]
```
- `cron`: 开启cron定时器，默认有一条`* * * * * root /usr/local/bin/cron-log -u www-data /usr/bin/php /var/www/artisan schedule:run`,若是不需要则在`Dockerfile`
  添加`ENV CRON_LARAVEL_SCHEDULE=false`
- `laravel-queue`: 使用`supervisor`执行`php /var/www/artisan queue:work --sleep=3 --tries=3`,默认开启8个进程
- `laravel-socket`: 使用`supervisor`执行`php /var/www/artisan socket start`,默认开启1个进程

>### 自定义配置文件
#### nginx
首先在项目中创建`.nginx-config`文件，然后在`Dockerfile`里加上下列
```dockerfile
COPY .nginx-config "$NGINX_DEFAULT_CONF"
```
php-fpm进程请使用 `$PHP_FPM_SOCK`，如：
```shell script
location ~ \.php$ {
    include fastcgi.conf;
    fastcgi_pass $PHP_FPM_SOCK;
}
```
#### supervisor
文件后缀`.ini`
```dockerfile
COPY $your_task "$SUPERVISOR_CONF_DIR"
```
示例：
```text
[program:cron]
command=cron -f
user=root
autostart=true
autorestart=true
numprocs=1
redirect_stderr=true
stdout_logfile=/var/log/supervisor/cron.log
```
#### php
文件后缀`.ini`
```dockerfile
COPY $your_ini "$PHP_INI_D"
```
#### php-fpm
文件后缀`.conf`
```dockerfile
COPY $your_conf "$PHP_FPM_CONF_D"
```
#### cron
无文件后缀
```dockerfile
COPY $your_file "$CRON_D"
```
推荐使用`/usr/local/bin/cron-log`来执行命令，通过此命令执行日志会记录到`/var/log/supervisor/cron.log`中，
示例：
```text
* * * * * root /usr/local/bin/cron-log -u www-data /usr/bin/php /var/www/artisan schedule:run
```
日志格式如下：
```text
--- [时间] [用户] [执行状态：SUCCESS|FAILURE] 执行的命令
命令输出
```
```text
--- [2020-12-24 17:30:01] [www-data] [FAILURE] /usr/bin/php /var/www/artisan schedule:run
Could not open input file: /var/www/artisan
--- [2020-12-24 17:31:01] [www-data] [FAILURE] /usr/bin/php /var/www/artisan schedule:run
Could not open input file: /var/www/artisan
...
```
**注意**：
- 执行程序需要使用绝对路径，比如：`/usr/local/bin/cron-log` 代替 `cron-cli`
##### cron-log
使用方式：
```text
Usage: cron-log [OPTIONS] COMMAND [ARG ...]

    Options:
      -h, --help                    帮助
      -u, --user string             执行用户
```
>### php安装额外扩展
项目`Dockerfile`里添加如下
```dockerfile
FROM zdzserver/docker-runtime:php7.4-fpm-ubuntu

## 增加pgsql扩展
RUN apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ${PHP_VERSION}-pgsql \
    ; \
    rm -rf /var/lib/apt/lists/*;
```