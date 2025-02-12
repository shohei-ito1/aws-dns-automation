#!/bin/bash

# ===============================
# Request SSL Certificate in AWS ACM (DNS Validation)
# ===============================

DOMAIN=$1
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "error=missing_domain_argument"
  exit 1
fi

# Retrieve Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  echo "error=hosted_zone_not_found, domain=$DOMAIN"
  exit 1
fi

echo "hosted_zone_id=$HOSTED_ZONE_ID"

# Retrieve additional domain list from script arguments
EXTRA_DOMAINS=("${@:2}")

# Process SAN parameter (Check if EXTRA_DOMAINS is empty)
if [ "${#EXTRA_DOMAINS[@]}" -gt 0 ]; then
  SAN_PARAM="--subject-alternative-names ${EXTRA_DOMAINS[@]}"
else
  SAN_PARAM=""
fi

# Request SSL Certificate
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$DOMAIN" \
  $SAN_PARAM \
  --validation-method DNS \
  --region "$AWS_REGION" \
  --query 'CertificateArn' --output text 2>&1)

# Error Handling
if [[ "$CERT_ARN" == *"InvalidInputException"* ]]; then
  echo "error=invalid_input, domain=$DOMAIN"
  exit 1
fi

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "error=failed_to_request_ssl_certificate, domain=$DOMAIN"
  exit 1
fi

echo "certificate_arn=$CERT_ARN"
echo "SSL certificate request completed successfully."

