#!/bin/bash

docker build -t certbot-acm .
docker tag certbot-acm lyrasis/certbot-acm:latest
docker push lyrasis/certbot-acm:latest
