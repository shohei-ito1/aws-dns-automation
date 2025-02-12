#!/bin/bash

# ===============================
# AWS Route 53 にホストゾーンを作成
# ===============================

DOMAIN=$1
DRY_RUN=$2

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Hosted zone を作成するコマンド:"
  echo "aws route53 create-hosted-zone --name $DOMAIN --caller-reference \$(date +%s) --query 'HostedZone.Id' --output text"

  echo "[Dry-Run] Hosted zone の情報を取得するコマンド:"
  echo "aws route53 get-hosted-zone --id <HOSTED_ZONE_ID> --query 'DelegationSet.NameServers' --output json"

  exit 0
fi

# ホストゾーンを作成
echo "Creating Hosted Zone for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "$(date +%s)" --query 'HostedZone.Id' --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Failed to create hosted zone."
  exit 1
fi

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# NS レコードを取得
echo "Retrieving NS records..."
NS_RECORDS=$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'DelegationSet.NameServers' --output json)

echo "==========================="
echo "以下のNSレコードを管理者に設定依頼してください:"
echo "${DOMAIN}.  IN  NS  $NS_RECORDS"
echo "==========================="



# ===============================
# 親ドメイン (Z104432328G24Z3B7DMOB) にサブドメインのNSレコードを追加
# ===============================

PARENT_HOSTED_ZONE_ID="Z104432328G24Z3B7DMOB"

# NS レコードを整形
NS_RECORDS_JSON=$(echo "$NS_RECORDS" | jq -c '[.[] | { "Value": . }]')

echo "Adding NS records to parent domain's hosted zone..."
aws route53 change-resource-record-sets --hosted-zone-id "$PARENT_HOSTED_ZONE_ID" --change-batch "{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$DOMAIN.\",
        \"Type\": \"NS\",
        \"TTL\": 300,
        \"ResourceRecords\": $NS_RECORDS_JSON
      }
    }
  ]
}"

if [ $? -eq 0 ]; then
  echo "Successfully added NS records for $DOMAIN to parent hosted zone ($PARENT_HOSTED_ZONE_ID)."
else
  echo "Error: Failed to add NS records to parent hosted zone."
  exit 1
fi

# ===============================
# 親ドメイン (Z104432328G24Z3B7DMOB) にサブドメインのNSレコードを追加（AWS Route 53 の場合）
# ===============================

PARENT_HOSTED_ZONE_ID="Z104432328G24Z3B7DMOB"

# NS レコードを整形
NS_RECORDS_JSON=$(echo "$NS_RECORDS" | jq -c '[.[] | { "Value": . }]')

echo "==============================="
echo "Route 53 の場合、以下のコマンドを実行してください:"
echo "aws route53 change-resource-record-sets --hosted-zone-id \"$PARENT_HOSTED_ZONE_ID\" --change-batch '{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$DOMAIN.\",
        \"Type\": \"NS\",
        \"TTL\": 300,
        \"ResourceRecords\": $NS_RECORDS_JSON
      }
    }
  ]
}'"
echo "==============================="

