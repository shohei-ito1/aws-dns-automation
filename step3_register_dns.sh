#!/bin/bash

# ===============================
# SSL 証明書の DNS 検証用 CNAME を登録
# ===============================

DOMAIN=$1
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "error=missing_domain_argument"
  exit 1
fi

# Route 53 の Hosted Zone ID を取得
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  echo "error=hosted_zone_not_found, domain=$DOMAIN"
  exit 1
fi

echo "hosted_zone_id=$HOSTED_ZONE_ID"

# ACM 証明書の ARN を取得
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "error=certificate_not_found, domain=$DOMAIN"
  exit 1
fi

echo "certificate_arn=$CERT_ARN"

# CNAME 検証レコードを取得（最大 10 回リトライ）
for i in {1..10}; do
  echo "Attempt $i: Retrieving SSL validation CNAME record..."
  CERT_VALIDATION_RECORDS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json)

  VALIDATION_NAME=$(echo "$CERT_VALIDATION_RECORDS" | jq -r '.Name // empty' | sed 's/\.$//')
  VALIDATION_VALUE=$(echo "$CERT_VALIDATION_RECORDS" | jq -r '.Value // empty')

  if [ -n "$VALIDATION_NAME" ] && [ -n "$VALIDATION_VALUE" ]; then
    echo "Validation record found!"
    break
  fi

  echo "CNAME record not yet available. Waiting for 30 seconds..."
  sleep 30
done

if [ -z "$VALIDATION_NAME" ] || [ -z "$VALIDATION_VALUE" ]; then
  echo "error=failed_to_retrieve_cname_records, certificate_arn=$CERT_ARN"
  exit 1
fi

echo "validation_name=$VALIDATION_NAME"
echo "validation_value=$VALIDATION_VALUE"

# Route 53 に CNAME レコードを追加
echo "Adding SSL validation record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "'"$VALIDATION_NAME"'",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'"$VALIDATION_VALUE"'"}]
    }
  }]
}'

if [ $? -ne 0 ]; then
  echo "error=failed_to_add_cname_to_route53"
  exit 1
fi

echo "SSL validation record added successfully."
echo "✅ Route 53 に CNAME を登録しました。"

