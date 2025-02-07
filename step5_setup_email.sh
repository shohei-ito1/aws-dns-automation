#!/bin/bash

# ===============================
# Step5: AWS Route 53 にメール送信用 DNS 設定 (Dry-Run対応)
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
  echo "[Dry-Run] SES ドメイン認証のコマンド:"
  echo "aws ses verify-domain-identity --domain $DOMAIN"

  echo "[Dry-Run] SES DKIM 設定のコマンド:"
  echo "aws ses verify-domain-dkim --domain $DOMAIN --query 'DkimTokens' --output json"

  echo "[Dry-Run] Route 53 の Hosted Zone ID を取得するコマンド:"
  echo "aws route53 list-hosted-zones-by-name --dns-name \"$DOMAIN\" --query \"HostedZones[0].Id\" --output text"

  echo "[Dry-Run] SPF & DMARC レコード追加のコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{
    \"Changes\": [
      { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"v=spf1 include:amazonses.com ~all\"}] } },
      { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"_dmarc.$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\"}] } }
    ]
  }'"
  exit 0
fi

# ===== 本番実行 =====

# SES のドメイン認証を実行
echo "Verifying domain identity with SES..."
aws ses verify-domain-identity --domain "$DOMAIN"

# SES の DKIM 設定を取得
echo "Retrieving DKIM records..."
DKIM_RECORDS=$(aws ses verify-domain-dkim --domain "$DOMAIN" --query 'DkimTokens' --output json)

DKIM1=$(echo "$DKIM_RECORDS" | jq -r '.[0]')
DKIM2=$(echo "$DKIM_RECORDS" | jq -r '.[1]')
DKIM3=$(echo "$DKIM_RECORDS" | jq -r '.[2]')

echo "==========================="
echo "以下の DKIM レコードを Route 53 に追加してください:"
echo "$DKIM1._domainkey.$DOMAIN CNAME $DKIM1.dkim.amazonses.com"
echo "$DKIM2._domainkey.$DOMAIN CNAME $DKIM2.dkim.amazonses.com"
echo "$DKIM3._domainkey.$DOMAIN CNAME $DKIM3.dkim.amazonses.com"
echo "==========================="

# Route 53 の Hosted Zone ID を取得
echo "Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

# SPF & DMARC 設定を実行
echo "Adding SPF & DMARC records to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [
    { "Action": "CREATE", "ResourceRecordSet": { "Name": "'"$DOMAIN"'", "Type": "TXT", "TTL": 300, "ResourceRecords": [{"Value": "\"v=spf1 include:amazonses.com ~all\""}] } },
    { "Action": "CREATE", "ResourceRecordSet": { "Name": "_dmarc.'"$DOMAIN"'", "Type": "TXT", "TTL": 300, "ResourceRecords": [{"Value": "\"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\""}] } }
  ]
}'

echo "SPF & DMARC records added."

