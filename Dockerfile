ARG alpine_version=3.23.0
ARG drogon_version=1.9.11
ARG trantor_version=1.5.24
ARG revision=1

FROM slacktomcat/alpine_drogon:${alpine_version}-${drogon_version}-${trantor_version}-${revision}-pgsql-redis

########################################################
# Essential packages for remote debugging and login in
########################################################
USER root
RUN apk update && apk upgrade && apk add gcc g++ openssh build-base cmake gdb rsync vim \
    && apk add --no-cache openssh && ssh-keygen -A && mkdir /root/.ssh && chmod 0700 /root/.ssh && \
    echo "root:root" | chpasswd && ln -s /etc/ssh/ssh_host_ed25519_key.pub /root/.ssh/authorized_keys

ADD . /code
WORKDIR /code

# Taken from - https://docs.docker.com/engine/examples/running_ssh_service/#environment-variables

RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# 22 for ssh server. 7777 for gdb server.
EXPOSE 22 7777

# If user don't exists: RUN adduser -s /bin/sh -D debugger
RUN mkdir /home/drogon/.ssh && chmod 0700 /home/drogon/.ssh && apk add shadow && chsh -s /bin/sh drogon && \
    echo 'drogon:pwd' | chpasswd && chown -R drogon:drogon /home/drogon

########################################################
# Add custom packages and development environment here
########################################################

RUN apk add --no-cache rabbitmq-c-dev openssl-dev git curl curl-dev hiredis-dev expat expat-dev \
    util-linux-dev postgresql-dev sqlite-libs asio-dev crypto++-dev && apk upgrade sqlite-libs && \
    git clone https://github.com/jpbarrette/curlpp.git && cd curlpp && cmake . && \
    make CXXFLAGS="-std=c++20 -Wall -O2" && make install && cd .. && \
    curl https://codeload.github.com/jtv/libpqxx/tar.gz/refs/tags/7.9.2 --output 7.9.2.tar.gz && \
    tar -xvf 7.9.2.tar.gz && cd libpqxx-7.9.2 && ./configure --prefix=/usr --enable-shared && \
    make CXXFLAGS="-std=c++20 -Wall -O2" && \
    make install

########################################################

CMD ["/usr/sbin/sshd", "-D"]
