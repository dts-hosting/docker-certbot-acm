#!/bin/bash

CERTBOT_DOMAIN=${1:-""}

echo -e "\nGenerating certificate/s for: $CERTBOT_DOMAIN\n"

certbot certonly --standalone --non-interactive --agree-tos \
  --email $CERTBOT_EMAIL \
  -w $CERTBOT_CERT_PATH \
  -d $CERTBOT_DOMAIN

CERT_ARN=$(
  aws acm list-certificates | jq -r ".CertificateSummaryList | .[]  | select ( .DomainName == \"${CERTBOT_DOMAIN}\") | .CertificateArn"
)

if [ -z "$CERT_ARN" ];
then
  echo -e "\nImporting new certificate for: $CERTBOT_DOMAIN\n"

  aws acm import-certificate \
    --certificate file://${CERTBOT_CERT_PATH}/cert.pem \
    --certificate-chain file://${CERTBOT_CERT_PATH}/chain.pem \
    --private-key file://${CERTBOT_CERT_PATH}/privkey.pem
else
  echo -e "\nUpdating existing certificate for: $CERTBOT_DOMAIN\n"

  aws acm import-certificate  \
    --certificate-arn $CERT_ARN \
    --certificate file://$CERTBOT_CERT_PATH/cert.pem \
    --certificate-chain file://$CERTBOT_CERT_PATH/chain.pem \
    --private-key file://$CERTBOT_CERT_PATH/privkey.pem
fi
