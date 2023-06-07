#!/bin/bash

USERNAME=$1

docker build -t certbot-acm .
docker tag certbot-acm $USERNAME/certbot-acm:latest
docker push $USERNAME/certbot-acm:latest
