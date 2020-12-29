# 初始化镜像
FROM ubuntu:20.04

COPY etc/apt/sources.list /etc/apt/sources.list


## 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    apt-get -y update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        net-tools \
        vim \
        curl \
        dos2unix \
    ;
