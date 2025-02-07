#!/bin/bash

# ===============================
# AWS ACM に SSL 証明書をリクエスト (DNS 検証用)
# ===============================

DOMAIN=$1
DRY_RUN=$2
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "error=missing_domain_argument"
  exit 1
fi

# Hosted Zone ID を取得
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  echo "error=hosted_zone_not_found, domain=$DOMAIN"
  exit 1
fi

echo "hosted_zone_id=$HOSTED_ZONE_ID"

# SSL証明書のリクエスト
CERT_ARN=$(aws acm request-certificate --domain-name "$DOMAIN" --validation-method DNS --region "$AWS_REGION" --query 'CertificateArn' --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "error=failed_to_request_ssl_certificate, domain=$DOMAIN"
  exit 1
fi

echo "certificate_arn=$CERT_ARN"
echo "✅ SSL 証明書のリクエストが完了しました。"

