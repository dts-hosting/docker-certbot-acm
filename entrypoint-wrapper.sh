#!/bin/bash

env | grep 'AWS_\|CERTBOT_\|ECS_' >> /etc/environment
rm /etc/cron.daily/*
ln -s /root/bootstrap.sh /etc/cron.daily/bootstrap
cron
/docker-entrypoint.sh "$@"
