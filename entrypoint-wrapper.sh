#!/bin/bash

env | grep CERTBOT_ >> /etc/environment
cron
rm /etc/cron.daily/*
ln -s /root/bootstrap.sh /etc/cron.daily/bootstrap
/docker-entrypoint.sh "$@"
