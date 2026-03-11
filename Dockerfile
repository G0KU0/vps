FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PORT=10000
ENV BORE_PORT=48251

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    dropbear \
    openssh-sftp-server \
    sudo curl wget git nano vim htop tmux screen \
    bash-completion net-tools iputils-ping dnsutils iproute2 \
    traceroute zip unzip tar gzip bzip2 xz-utils p7zip-full \
    python3 python3-pip python3-venv python3-full build-essential gcc g++ \
    make cmake pkg-config libssl-dev locales cron rsync jq tree \
    ncdu procps lsof file man-db less openssl ca-certificates \
    gnupg mc software-properties-common apt-transport-https \
    lsb-release nginx passwd supervisor pipx \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# PIP engedélyezés
RUN rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED

# SFTP-SERVER symlink MINDEN lehetséges helyre
RUN mkdir -p /usr/libexec /usr/lib/sftp && \
    SFTP_BIN=$(find / -name "sftp-server" -type f 2>/dev/null | head -1) && \
    echo "SFTP-server megtalálva: ${SFTP_BIN}" && \
    ln -sf "${SFTP_BIN}" /usr/libexec/sftp-server && \
    ln -sf "${SFTP_BIN}" /usr/local/bin/sftp-server && \
    ln -sf "${SFTP_BIN}" /usr/bin/sftp-server && \
    ln -sf "${SFTP_BIN}" /usr/lib/sftp-server && \
    chmod +x "${SFTP_BIN}" && \
    ls -la /usr/libexec/sftp-server /usr/lib/openssh/sftp-server

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

RUN cd /tmp && \
    curl -fsSL https://github.com/filebrowser/filebrowser/releases/download/v2.31.2/linux-amd64-filebrowser.tar.gz -o filebrowser.tar.gz && \
    tar xzf filebrowser.tar.gz && \
    mv filebrowser /usr/local/bin/filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm -f filebrowser.tar.gz LICENSE README.md && \
    /usr/local/bin/filebrowser version

# Dropbear SSH kulcsok
RUN rm -f /etc/dropbear/dropbear_rsa_host_key \
          /etc/dropbear/dropbear_ecdsa_host_key \
          /etc/dropbear/dropbear_ed25519_host_key && \
    mkdir -p /etc/dropbear && \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key && \
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key && \
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# Felhasználók
RUN echo 'root:2003' | chpasswd && \
    sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd

RUN mkdir -p /workspace /data /var/www/html /root/.ssh && \
    chmod 700 /root /root/.ssh

COPY start.sh /start.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf.template /etc/nginx/nginx.conf.template
RUN chmod +x /start.sh

WORKDIR /workspace
EXPOSE 10000
CMD ["/start.sh"]
