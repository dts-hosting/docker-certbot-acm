#!/bin/bash

CERTBOT_DOMAIN=${1:-""}
DATE_EXPIRATION_INTERVAL=${2:-"28"}

CERT_ARN=$(
  aws acm list-certificates --includes keyTypes=RSA_2048,EC_prime256v1 | jq -r ".CertificateSummaryList | .[]  | select ( .DomainName == \"${CERTBOT_DOMAIN}\") | .CertificateArn"
)

echo -e "\nChecking status for: $CERTBOT_DOMAIN\n"

if [ -z "$CERT_ARN" ];
then
  echo -e "\nCertificate does not exist: $CERTBOT_DOMAIN\n"
  exit 1
fi

DATE_EXPIRATION=$(
  aws acm describe-certificate --certificate-arn $CERT_ARN | jq -r '.Certificate.NotAfter'
)
DATE_EXPIRATION=$(date -d $DATE_EXPIRATION +%s)
DATE_EXPIRATION_FROM_NOW=$(date -d "+$DATE_EXPIRATION_INTERVAL days" +%s)

if [ "$DATE_EXPIRATION_FROM_NOW" -gt "$DATE_EXPIRATION" ];
then
  echo -e "\nCertificate is up for renewal: $CERTBOT_DOMAIN [$DATE_EXPIRATION]\n"
  exit 1
fi

exit 0
