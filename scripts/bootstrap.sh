#!/bin/bash

if [ "$CERTBOT_ENABLED" != "true" ]
then
  echo -e "\nCertbot disabled, peacing out!\n"
  exit 0
fi

IFS=, read -a domains <<< "$CERTBOT_DOMAINS"
for CERTBOT_DOMAIN in "${domains[@]}"; do
  echo -e "\nEvaluating certificate for: $CERTBOT_DOMAIN\n"

  /root/check_status.sh $CERTBOT_DOMAIN
  status=$?

  if test $status -eq 1
  then
    echo -e "\nProcessing certificate for: $CERTBOT_DOMAIN\n"
    /root/create_cert.sh $CERTBOT_DOMAIN
    sleep 5 # Wait for cert creation
    /root/register_with_alb.sh $CERTBOT_DOMAIN
  else
    echo -e "\nCertificate exists and does not require renewal for: $CERTBOT_DOMAIN\n"
  fi
done
