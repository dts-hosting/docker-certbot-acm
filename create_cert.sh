#!/bin/bash

CERTBOT_DOMAIN=${1:-""}

echo -e "\nGenerating certificate/s for: $CERTBOT_DOMAIN\n"

mkdir -p $CERTBOT_CERT_PATH
# TODO: delete any existing certs?

certbot certonly --webroot --non-interactive --agree-tos \
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
    --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
    --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
    --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem
else
  echo -e "\nUpdating existing certificate for: $CERTBOT_DOMAIN\n"

  aws acm import-certificate  \
    --certificate-arn $CERT_ARN \
    --certificate fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/cert.pem \
    --certificate-chain fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/chain.pem \
    --private-key fileb://$CERTBOT_CERT_PATH/$CERTBOT_DOMAIN/privkey.pem
fi
