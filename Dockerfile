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
    lsb-release nginx passwd sshpass \
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

# SSH ELŐKONFIGURÁCIÓ — már a build-nél beállítjuk
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root /root/.ssh && \
    # Root shell beállítása
    sed -i 's|root:x:0:0:root:/root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd && \
    # Root jelszó beállítása (2003)
    echo 'root:2003' | chpasswd && \
    # Root fiók feloldása
    passwd -u root 2>/dev/null || true && \
    # SSH host kulcsok generálása
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N '' -q && \
    ssh-keygen -t ecdsa -b 521 -f /etc/ssh/ssh_host_ecdsa_key -N '' -q && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q && \
    chmod 600 /etc/ssh/ssh_host_*_key && \
    chmod 644 /etc/ssh/ssh_host_*_key.pub

# SSHD_CONFIG — teljes felülírás a build-nél
RUN echo 'Port 22' > /etc/ssh/sshd_config && \
    echo 'AddressFamily any' >> /etc/ssh/sshd_config && \
    echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config && \
    echo 'HostKey /etc/ssh/ssh_host_rsa_key' >> /etc/ssh/sshd_config && \
    echo 'HostKey /etc/ssh/ssh_host_ecdsa_key' >> /etc/ssh/sshd_config && \
    echo 'HostKey /etc/ssh/ssh_host_ed25519_key' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PermitEmptyPasswords no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'AuthorizedKeysFile .ssh/authorized_keys' >> /etc/ssh/sshd_config && \
    echo 'UsePAM no' >> /etc/ssh/sshd_config && \
    echo 'Subsystem sftp /usr/lib/openssh/sftp-server' >> /etc/ssh/sshd_config && \
    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config && \
    echo 'GatewayPorts yes' >> /etc/ssh/sshd_config && \
    echo 'X11Forwarding no' >> /etc/ssh/sshd_config && \
    echo 'TCPKeepAlive yes' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 30' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 120' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd yes' >> /etc/ssh/sshd_config && \
    echo 'MaxAuthTries 10' >> /etc/ssh/sshd_config && \
    echo 'MaxSessions 20' >> /etc/ssh/sshd_config && \
    echo 'LoginGraceTime 120' >> /etc/ssh/sshd_config && \
    echo 'AcceptEnv LANG LC_*' >> /etc/ssh/sshd_config && \
    echo 'LogLevel INFO' >> /etc/ssh/sshd_config

# SSH CONFIG TESZTELÉS a build-nél
RUN /usr/sbin/sshd -t

RUN mkdir -p /workspace /data /var/www/html

COPY start.sh /start.sh
COPY nginx.conf.template /etc/nginx/nginx.conf.template
RUN chmod +x /start.sh

WORKDIR /workspace
EXPOSE 10000
CMD ["/start.sh"]
