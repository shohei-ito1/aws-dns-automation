#!/bin/bash

# ===============================
# Step4: AWS Route 53 にメール送信用 DNS 設定 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# SES ドメイン認証コマンド
VERIFY_DOMAIN_CMD="aws ses verify-domain-identity --domain $DOMAIN"

# SES DKIM 設定コマンド
VERIFY_DKIM_CMD="aws ses verify-domain-dkim --domain $DOMAIN --query 'DkimTokens' --output json"

# SPF & DMARC 設定コマンド (Route 53)
ADD_SPF_DMARC_CMD="aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{
  \"Changes\": [
    { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\"v=spf1 include:amazonses.com ~all\\"\"}] } },
    { \"Action\": \"CREATE\", \"ResourceRecordSet\": { \"Name\": \"_dmarc.$DOMAIN\", \"Type\": \"TXT\", \"TTL\": 300, \"ResourceRecords\": [{\"Value\": \"\\"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\\"\"}] } }
  ]
}'"

# Dry-Run モードならコマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] SES ドメイン認証のコマンド:"
  echo "$VERIFY_DOMAIN_CMD"
  echo "[Dry-Run] SES DKIM 設定のコマンド:"
  echo "$VERIFY_DKIM_CMD"
  echo "[Dry-Run] SPF & DMARC レコード追加のコマンド:"
  echo "$ADD_SPF_DMARC_CMD"
  exit 0
fi

# SES のドメイン認証を実行
eval $VERIFY_DOMAIN_CMD

# SES の DKIM 設定を取得
DKIM_RECORDS=$(eval $VERIFY_DKIM_CMD)

DKIM1=$(echo $DKIM_RECORDS | jq -r '.[0]')
DKIM2=$(echo $DKIM_RECORDS | jq -r '.[1]')
DKIM3=$(echo $DKIM_RECORDS | jq -r '.[2]')

echo "==========================="
echo "以下の DKIM レコードを Route 53 に追加してください:"
echo "$DKIM1._domainkey.$DOMAIN CNAME $DKIM1.dkim.amazonses.com"
echo "$DKIM2._domainkey.$DOMAIN CNAME $DKIM2.dkim.amazonses.com"
echo "$DKIM3._domainkey.$DOMAIN CNAME $DKIM3.dkim.amazonses.com"
echo "==========================="

# SPF & DMARC 設定を表示
echo "==========================="
echo "以下の SPF & DMARC レコードを Route 53 に追加してください:"
echo "$DOMAIN TXT \"v=spf1 include:amazonses.com ~all\""
echo "_dmarc.$DOMAIN TXT \"v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; ruf=mailto:dmarc-reports@example.com; pct=100\""
echo "==========================="

# SPF & DMARC 設定を実行
eval $ADD_SPF_DMARC_CMD

