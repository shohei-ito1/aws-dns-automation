#!/bin/bash

# ===============================
# Step3: AWS Route 53 にメール送信用 DNS 設定 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] SES ドメイン認証のコマンド:"
  echo "aws ses verify-domain-identity --domain $DOMAIN"
  echo "[Dry-Run] SES DKIM 設定のコマンド:"
  echo "aws ses verify-domain-dkim --domain $DOMAIN --query 'DkimTokens' --output json"
  echo "[Dry-Run] SPF & DMARC レコード追加のコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{
    \"Changes\": [
      { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\\"v=spf1 include:amazonses.com ~all\\\"\"}] } },
      { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"_dmarc.$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\\"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\\\"\"}] } }
    ]
  }'"
  exit 0
fi

# SES のドメイン認証
aws ses verify-domain-identity --domain $DOMAIN

# DKIM 設定
DKIM_RECORDS=$(aws ses verify-domain-dkim --domain $DOMAIN --query 'DkimTokens' --output json)

DKIM1=$(echo $DKIM_RECORDS | jq -r '.[0]')
DKIM2=$(echo $DKIM_RECORDS | jq -r '.[1]')
DKIM3=$(echo $DKIM_RECORDS | jq -r '.[2]')

echo "==========================="
echo "以下の DKIM レコードを Route 53 に追加してください:"
echo "$DKIM1._domainkey.$DOMAIN CNAME $DKIM1.dkim.amazonses.com"
echo "$DKIM2._domainkey.$DOMAIN CNAME $DKIM2.dkim.amazonses.com"
echo "$DKIM3._domainkey.$DOMAIN CNAME $DKIM3.dkim.amazonses.com"
echo "==========================="

# SPF & DMARC 設定
echo "==========================="
echo "以下の SPF & DMARC レコードを Route 53 に追加してください:"
echo "$DOMAIN TXT \"v=spf1 include:amazonses.com ~all\""
echo "_dmarc.$DOMAIN TXT \"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\""
echo "==========================="

