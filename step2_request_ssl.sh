#!/bin/bash

# ===============================
# AWS ACM に SSL 証明書をリクエスト & Route 53 に DNS レコードを追加 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# Dry-Run モードなら、すべての AWS コマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Hosted Zone ID を取得するコマンド:"
  echo "aws route53 list-hosted-zones-by-name --dns-name \"$DOMAIN\" --query \"HostedZones[0].Id\" --output text"
  
  echo "[Dry-Run] SSL証明書をリクエストするコマンド:"
  echo "aws acm request-certificate --domain-name $DOMAIN --validation-method DNS --region $AWS_REGION --query 'CertificateArn' --output text"
  
  echo "[Dry-Run] SSL検証用 CNAME レコードを取得するコマンド:"
  echo "aws acm describe-certificate --certificate-arn <CERT_ARN> --region $AWS_REGION --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json"
  
  echo "[Dry-Run] Route 53 に CNAME レコードを追加するコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{
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

# ===== 本番実行 =====

# Route 53 の Hosted Zone ID を取得
echo "Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

# SSL証明書のリクエスト
echo "Requesting SSL certificate for $DOMAIN..."
CERT_ARN=$(aws acm request-certificate --domain-name "$DOMAIN" --validation-method DNS --region "$AWS_REGION" --query 'CertificateArn' --output text)

if [ -z "$CERT_ARN" ]; then
  echo "Error: Failed to request SSL certificate"
  exit 1
fi

echo "Certificate ARN: $CERT_ARN"

# SSL証明書の検証用 CNAME レコード取得
echo "Retrieving SSL validation CNAME record..."
CERT_VALIDATION_RECORDS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.DomainValidationOptions[0].ResourceRecord' --output json)

VALIDATION_NAME=$(echo "$CERT_VALIDATION_RECORDS" | jq -r '.Name')
VALIDATION_VALUE=$(echo "$CERT_VALIDATION_RECORDS" | jq -r '.Value')

# Route 53 に CNAME レコードを追加
echo "Adding SSL validation record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "'"$VALIDATION_NAME"'",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'"$VALIDATION_VALUE"'"}]
    }
  }]
}'

echo "SSL validation record added."
echo "SSL証明書の DNS 検証レコードを Route 53 に追加しました。"
echo "証明書の ARN: $CERT_ARN"
