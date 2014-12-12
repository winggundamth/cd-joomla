# MySQL
#
# VERSION 1.0

FROM ubuntu:14.10
MAINTAINER Jirayut Nimsaeng <w [at] winginfotech.net>

# 1) Some fixes from https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
# 2) Configure timezone, locale and fix environment
# 3) Make sure the package repository is up to date
#    Required to build and run apt-cacher on builder machine first
# 4) Config rsyslog
# 5) Install and config apache and php
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV FAKE_CHROOT 1
ENV INITRD No
ADD build-files /build-files
RUN mv /usr/bin/ischroot /usr/bin/ischroot.original && \
    mv /build-files/ischroot /usr/bin/ischroot && \
    echo "Etc/UTC" > /etc/timezone && \
    locale-gen en_US.UTF-8 && \
    dpkg-reconfigure -f noninteractive locales && \
    dpkg-reconfigure -f noninteractive tzdata && \
    update-locale LANG=en_US.UTF-8 && \
    echo 'Acquire::http::Proxy "http://172.17.42.1:3142";' > /etc/apt/apt.conf.d/11proxy && \
    apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y autoremove && \
    sed -i 's/log\//log\/syslog\//g' /etc/rsyslog.d/50-default.conf && \
    sed -i 's/#cron\./cron\./g' /etc/rsyslog.d/50-default.conf && \
    sed -i 's/#daemon\./deamon\./g' /etc/rsyslog.d/50-default.conf && \
    sed -i 's/#mail\./mail\./g' /etc/rsyslog.d/50-default.conf && \
    sed -i 's/#user\./user\./g' /etc/rsyslog.d/50-default.conf && \
    sed -i 's/^news\./#news\./g' /etc/rsyslog.d/50-default.conf && \
    service rsyslog start && \
    service rsyslog stop && \
    echo 'Acquire::http::Proxy "http://172.17.42.1:3142";' > /etc/apt/apt.conf.d/11proxy && \
    echo mysql-server mysql-server/root_password password P@ssw0rd | sudo debconf-set-selections && \
    echo mysql-server mysql-server/root_password_again password P@ssw0rd | sudo debconf-set-selections && \
    apt-get install -y mysql-server wget && \
    sed -i 's/bind-address/#bind-address/g' /etc/mysql/my.cnf && \
    mv /build-files/start.sh /start.sh && \
    chown root:root /start.sh && \
    chmod 700 /start.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /build-files /etc/apt/apt.conf.d/11proxy
RUN service mysql start && \
    sleep 3 && \
    mysql -u root -h localhost -pP@ssw0rd -e "DELETE FROM mysql.user WHERE user='root'; GRANT ALL PRIVILEGES ON *.* TO root@'%' IDENTIFIED BY 'P@ssw0rd' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE DATABASE joomla;" && \
    wget http://172.17.42.1:81/joomla.sql && \
    mysql -u root -pP@ssw0rd joomla < joomla.sql && \
    service mysql stop && \
    rm -rf joomla.sql

VOLUME ["/var/log", "/var/lib/mysql", "/etc/mysql"]

# How to run as daemon
CMD /start.sh

# Expose port
EXPOSE 3306
