# Docker Certbot ACM

A Docker + Nginx + Certbot + ACM + ALB integration for ECS.

Provides scripts to:

- Generate certificates using certbot
- Upload certificates to ACM
- Register certificates with an ALB

Certificates are status checked using `cron.daily`.

*Note: to generate certificate/s the first time without
waiting for cron see [run.sh](./test/run.sh) as an example of
directly invoking the certificate bootstrap process.*

The Docker image is based on Nginx which runs persistently
to handle `http` requests only (expected to be routed
from an ALB http listener):

- handles `.well-known/acme-challenge` for certbot
- includes a friendly health-check path `/health` (to confirm/test routing)
- otherwise catches all and redirects http to https

## Task definition (example)

To run in ECS include the image in a task definition:

```json
{
  "name": "certbot",
  "image": "${username}/certbot-acm:latest",
  "networkMode": "${network_mode}",
  "essential": true,
  "environment": [
    {
      "name": "CERTBOT_ALB_NAME",
      "value": "${certbot_alb_name}"
    },
    {
      "name": "CERTBOT_DOMAINS",
      "value": "${certbot_domains}"
    },
    {
      "name": "CERTBOT_EMAIL",
      "value": "${certbot_email}"
    },
    {
      "name": "CERTBOT_ENABLED",
      "value": "${certbot_enabled}"
    }
  ],
  "portMappings": [
    {
      "containerPort": 80
    }
  ]
}
```

## Build

```bash
docker build -t certbot-acm .
docker run -it -p 80:80 --rm certbot-acm

# if checks out (requires push access to Docker Hub repository)
./build.sh lyrasis
```
