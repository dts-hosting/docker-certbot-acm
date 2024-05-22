#!/bin/bash

CERTBOT_DOMAIN=${1:-""}

echo -e "\nGenerating certificate/s for: $CERTBOT_DOMAIN\n"

mkdir -p $CERTBOT_CERT_PATH

certbot certonly --webroot --non-interactive --agree-tos \
  --email $CERTBOT_EMAIL \
  -w $CERTBOT_CERT_PATH \
  -d $CERTBOT_DOMAIN

CERT_ARN=$(
  aws acm list-certificates \
    --includes keyTypes=RSA_2048,EC_prime256v1 \
    --query "CertificateSummaryList[?DomainName=='${CERTBOT_DOMAIN}' && Status=='ISSUED' && InUse==\`true\`].CertificateArn" --output text
)

# Cloudfront requires certificates to be in us-east-1
# We do not query for InUse because cloudfront is not used for every site
USE1_CERT_ARN=$(
  aws acm list-certificates \
    --includes keyTypes=RSA_2048,EC_prime256v1 \
    --query "CertificateSummaryList[?DomainName=='${CERTBOT_DOMAIN}' && Status=='ISSUED'].CertificateArn" \
    --output text --region us-east-1
)

# Handle the alb certificate
if [ -z "$CERT_ARN" ];
then
  echo -e "\nImporting new certificate for: $CERTBOT_DOMAIN\n"

  NEW_CERT_ARN=$(
    aws acm import-certificate \
      --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
      --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
      --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem \
    | jq -r '.CertificateArn'
  )

  CERTBOT_ALB_ARN=$(
    aws elbv2 describe-load-balancers --names $CERTBOT_ALB_NAME | jq -r '.LoadBalancers[0].LoadBalancerArn'
  )
  CERTBOT_ALB_HTTPS_ARN=$(
    aws elbv2 describe-listeners --load-balancer-arn $CERTBOT_ALB_ARN | jq -r '.Listeners[] | select(.Protocol | contains("HTTPS")) | .ListenerArn'
  )

  echo -e "\nRegistering certificate with ALB for: $CERTBOT_DOMAIN [$CERTBOT_ALB_NAME] [$CERTBOT_ALB_ARN] [$CERTBOT_ALB_HTTPS_ARN]\n"

  aws elbv2 add-listener-certificates --listener-arn $CERTBOT_ALB_HTTPS_ARN --certificates CertificateArn=$NEW_CERT_ARN
else
  echo -e "\nUpdating existing certificate for: $CERTBOT_DOMAIN\n"

  aws acm import-certificate  \
    --certificate-arn $CERT_ARN \
    --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
    --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
    --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem
fi

# Handle the cloudfront certificate
if [ -z "$USE1_CERT_ARN" ]; then
  echo -e "\nImporting new certificate to us-east-1: $CERTBOT_DOMAIN\n"

  aws acm import-certificate \
    --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
    --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
    --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem \
    --region us-east-1
else
  echo -e "\nUpdating existing certificate in us-east-1: $CERTBOT_DOMAIN\n"

  aws acm import-certificate \
    --certificate-arn $USE1_CERT_ARN \
    --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
    --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
    --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem \
    --region us-east-1
fi
