#!/bin/bash

rm -rf /var/run/rsyslogd.pid
service rsyslog start
cron
mysqld --datadir=/var/lib/mysql --user=mysql
