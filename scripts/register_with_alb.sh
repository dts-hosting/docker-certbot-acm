#!/bin/bash

CERTBOT_DOMAIN=${1:-""}

CERT_ARN=$(
  aws acm list-certificates | jq -r ".CertificateSummaryList | .[]  | select ( .DomainName == \"${CERTBOT_DOMAIN}\") | .CertificateArn"
)
CERTBOT_ALB_ARN=$(
  aws elbv2 describe-load-balancers --names $CERTBOT_ALB_NAME | jq -r '.LoadBalancers[0].LoadBalancerArn'
)
CERTBOT_ALB_HTTPS_ARN=$(
  aws elbv2 describe-listeners --load-balancer-arn $CERTBOT_ALB_ARN --names $CERTBOT_ALB_NAME | jq -r '.LoadBalancers[0].LoadBalancerArn'
)

if [ -n "$CERT_ARN" ];
then
  echo -e "\nRegistering certificate with ALB for: $CERTBOT_DOMAIN [$CERTBOT_ALB_NAME] [$CERTBOT_ALB_ARN] [$CERTBOT_ALB_HTTPS_ARN]\n"

  aws elbv2 add-listener-certificates --listener-arn $CERTBOT_ALB_HTTPS_ARN --certificates CertificateArn=$CERT_ARN
else
  echo -e "\nCertificate not found for ALB registration: $CERTBOT_DOMAIN\n"
fi
