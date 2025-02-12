#!/bin/bash

# ===============================
# Step6: AWS Route 53 にメール送信用 DNS 設定 (完全自動化)
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
  echo "aws ses verify-domain-identity --domain $DOMAIN --region $AWS_REGION"

  echo "[Dry-Run] SES DKIM 設定のコマンド:"
  echo "aws ses verify-domain-dkim --domain $DOMAIN --query 'DkimTokens' --output json --region $AWS_REGION"

  echo "[Dry-Run] Route 53 に DKIM, SPF, DMARC, MX レコードを追加するコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{JSON設定}' --region $AWS_REGION"

  exit 0
fi

# ===== 本番実行 =====

# SES のドメイン認証を実行
echo "🔹 Verifying domain identity with SES..."
IDENTITY_VERIFICATION=$(aws ses verify-domain-identity --domain "$DOMAIN" --region "$AWS_REGION")

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to verify domain identity for $DOMAIN"
  exit 1
fi

echo "✅ Domain identity verification request sent."

# SES の DKIM 設定を取得
echo "🔹 Retrieving DKIM records..."
DKIM_RECORDS=$(aws ses verify-domain-dkim --domain "$DOMAIN" --query 'DkimTokens' --output json --region "$AWS_REGION")

if [ $? -ne 0 ] || [ -z "$DKIM_RECORDS" ]; then
  echo "❌ Error: Failed to retrieve DKIM tokens for $DOMAIN"
  exit 1
fi

DKIM1=$(echo "$DKIM_RECORDS" | jq -r '.[0]')
DKIM2=$(echo "$DKIM_RECORDS" | jq -r '.[1]')
DKIM3=$(echo "$DKIM_RECORDS" | jq -r '.[2]')

echo "✅ DKIM records retrieved."

# Route 53 の Hosted Zone ID を取得
echo "🔹 Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text --region "$AWS_REGION")

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "❌ Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "✅ Using Hosted Zone ID: $HOSTED_ZONE_ID"

# DKIM, SPF, DMARC, MX 設定を Route 53 に追加
echo "🔹 Adding DKIM, SPF, DMARC, and MX records to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --region "$AWS_REGION" --change-batch "{
  \"Changes\": [
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\\"v=spf1 include:amazonses.com ~all\\\"\"}] } },
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"_dmarc.$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\\"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\\\"\"}] } },
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$DOMAIN\", \"Type\": \"MX\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"10 inbound-smtp.$AWS_REGION.amazonaws.com\"}] } },
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$DKIM1._domainkey.$DOMAIN\", \"Type\": \"CNAME\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"$DKIM1.dkim.amazonses.com\"}] } },
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$DKIM2._domainkey.$DOMAIN\", \"Type\": \"CNAME\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"$DKIM2.dkim.amazonses.com\"}] } },
    { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"$DKIM3._domainkey.$DOMAIN\", \"Type\": \"CNAME\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"$DKIM3.dkim.amazonses.com\"}] } }
  ]
}"

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to add DNS records to Route 53"
  exit 1
fi

echo "✅ SPF, DMARC, MX, and DKIM records added to Route 53."

