#!/bin/bash

# ===============================
# AWS Route 53 にホストゾーンを作成 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# コマンドを変数に格納
CREATE_HOSTED_ZONE_CMD="aws route53 create-hosted-zone --name $DOMAIN --caller-reference \$(date +%s) --query 'HostedZone.Id' --output text"
GET_HOSTED_ZONE_CMD="aws route53 get-hosted-zone --id <HOSTED_ZONE_ID> --query 'DelegationSet.NameServers' --output json"

# Dry-Run モードならコマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Hosted zone を作成するコマンド:"
  echo "$CREATE_HOSTED_ZONE_CMD"
  echo "[Dry-Run] Hosted zone の情報を取得するコマンド:"
  echo "$GET_HOSTED_ZONE_CMD"
  exit 0
fi

# 実際にホストゾーンを作成
HOSTED_ZONE_ID=$(eval $CREATE_HOSTED_ZONE_CMD)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Failed to create hosted zone."
  exit 1
fi

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# NS レコードを取得
NS_RECORDS=$(aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --query 'DelegationSet.NameServers' --output json)

echo "==========================="
echo "以下のNSレコードを管理者に設定依頼してください:"
echo "==========================="
echo "${DOMAIN}.  IN  NS  $NS_RECORDS"
echo "==========================="

