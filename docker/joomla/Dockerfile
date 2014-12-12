# Joomla
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
    mkdir -p /root/.ssh && \
    mv /build-files/id_rsa /root/.ssh/id_rsa && \
    chmod 700 /root/.ssh && \
    chown 400 /root/.ssh/id_rsa && \
    echo 'Acquire::http::Proxy "http://172.17.42.1:3142";' > /etc/apt/apt.conf.d/11proxy && \
    echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections && \
    echo "deb http://ppa.launchpad.net/ondrej/php5-5.6/ubuntu utopic main" > /etc/apt/sources.list.d/ondrej-php5-5_6-utopic.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E5267A6C && \
    apt-get install -y apache2-mpm-event php5-fpm php5-mysql git postfix unzip supervisor && \
    sed -i "s/^output_buffering = .*/output_buffering = Off/g" /etc/php5/fpm/php.ini && \
    echo "ServerName localhost" > /etc/apache2/conf-available/fqdn.conf && \
    a2enconf fqdn && \
    a2enmod proxy_fcgi rewrite && \
    sed -i "/#Include/a \        ProxyPassMatch ^/(.*\.php(/.*)?)$ unix:/var/run/php5-fpm.sock|fcgi://127.0.0.1:9000/var/www/html/" /etc/apache2/sites-enabled/000-default.conf && \
    sed -i "/ProxyPassMatch/a \        <Directory /var/www/html>\n                AllowOverride All\n        </Directory>" /etc/apache2/sites-enabled/000-default.conf && \
    cp -av /usr/sbin/apache2ctl /usr/sbin/apache2ctl.orig && \
    cp -av /etc/init.d/php5-fpm /etc/init.d/php5-fpm.orig && \
    sed -i 's/    $HTTPD ${APACHE_ARGUMENTS} -k $ARGV/    $HTTPD ${APACHE_ARGUMENTS} -DFOREGROUND -k $ARGV/g' /usr/sbin/apache2ctl && \
    sed -i 's/--daemonize/--nodaemonize/g' /etc/init.d/php5-fpm && \
    mv /build-files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \
    mv /build-files/start.sh /start.sh && \
    chown root:root /start.sh && \
    chmod 700 /start.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /build-files /etc/apt/apt.conf.d/11proxy
RUN cd /var/www/html/ && \
    rm -rf * && \
    ssh-keyscan -p 10022 -H 172.17.42.1 >> /root/.ssh/known_hosts && \
    git clone ssh://git@172.17.42.1:10022/root/joomla.git . && \
    chown -R www-data:www-data /var/www/

VOLUME ["/var/log", "/etc/apache2", "/etc/ssl", "/etc/php5", "/var/www/logs", "/var/www/uploads"]

# How to run as daemon
CMD /start.sh

# Expose port
EXPOSE 80 443
