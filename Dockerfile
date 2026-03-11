FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    openssh-server sudo curl wget git nano vim htop tmux screen \
    bash-completion net-tools iputils-ping dnsutils iproute2 \
    traceroute zip unzip tar gzip bzip2 xz-utils p7zip-full \
    python3 python3-pip python3-venv build-essential gcc g++ \
    make cmake pkg-config libssl-dev locales cron rsync jq tree \
    ncdu procps lsof file man-db less openssl ca-certificates \
    gnupg mc software-properties-common apt-transport-https \
    lsb-release nginx passwd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
    -O /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

RUN wget -q https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-unknown-linux-musl.tar.gz \
    -O /tmp/bore.tar.gz && cd /tmp && tar xzf bore.tar.gz && \
    mv bore /usr/local/bin/bore && chmod +x /usr/local/bin/bore && \
    rm -f /tmp/bore.tar.gz

RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

RUN mkdir -p /workspace /data /var/www/html /var/run/sshd /root/.ssh

COPY start.sh /start.sh
COPY nginx.conf.template /etc/nginx/nginx.conf.template
RUN chmod +x /start.sh

WORKDIR /workspace
EXPOSE 10000
CMD ["/start.sh"]
