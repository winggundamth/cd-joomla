#!/bin/bash

rm -rf /var/run/rsyslogd.pid
service rsyslog start
cron
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
