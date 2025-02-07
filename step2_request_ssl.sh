#!/bin/bash

# ===============================
# Step2-1: AWS ACM に SSL証明書をリクエスト & Route 53 に DNS レコードを追加
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション
AWS_REGION="us-east-1"  # CloudFront 用なら us-east-1

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# Route 53 の Hosted Zone ID を取得
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] SSL証明書をリクエストするコマンド:"
  echo "aws acm request-certificate --domain-name $DOMAIN --validation-method DNS --region $AWS_REGION --query 'CertificateArn' --output text"
  echo "[Dry-Run] SSL検証用 CNAME レコードを取得するコマンド:"
  echo "aws acm describe-certificate --certificate-arn <CERT_ARN> --region $AWS_REGION --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json"
  echo "[Dry-Run] Route 53 に CNAME レコードを追加するコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"<VALIDATION_NAME>\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"<VALIDATION_VALUE>\"}]
      }
    }]
  }'"
  exit 0
fi

# ===============================
# SSL証明書のリクエスト
# ===============================
CERT_ARN=$(aws acm request-certificate --domain-name $DOMAIN --validation-method DNS --region $AWS_REGION --query 'CertificateArn' --output text)

if [ -z "$CERT_ARN" ]; then
  echo "Error: Failed to request SSL certificate"
  exit 1
fi

echo "Certificate ARN: $CERT_ARN"

# ===============================
# DNS検証用レコードを取得 & 自動登録
# ===============================
CERT_VALIDATION_RECORDS=$(aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION --query "Certificate.DomainValidationOptions[0].ResourceRecord" --output json)

VALIDATION_NAME=$(echo $CERT_VALIDATION_RECORDS | jq -r '.Name')
VALIDATION_VALUE=$(echo $CERT_VALIDATION_RECORDS | jq -r '.Value')

echo "Adding SSL validation record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch "{
  \"Changes\": [{
    \"Action\": \"CREATE\",
    \"ResourceRecordSet\": {
      \"Name\": \"$VALIDATION_NAME\",
      \"Type\": \"CNAME\",
      \"TTL\": 300,
      \"ResourceRecords\": [{\"Value\": \"$VALIDATION_VALUE\"}]
    }
  }]
}"

echo "SSL validation record added."

echo "SSL証明書の DNS 検証レコードを Route 53 に追加しました。発行状況は別のスクリプトで確認してください。"
echo "証明書の ARN: $CERT_ARN"

