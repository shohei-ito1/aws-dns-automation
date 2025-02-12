#!/bin/bash

# ===============================
# Create a Hosted Zone in AWS Route 53
# ===============================

DOMAIN=$1
DRY_RUN=$2

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Command to create hosted zone:"
  echo "aws route53 create-hosted-zone --name $DOMAIN --caller-reference \$(date +%s) --query 'HostedZone.Id' --output text"

  echo "[Dry-Run] Command to retrieve hosted zone information:"
  echo "aws route53 get-hosted-zone --id <HOSTED_ZONE_ID> --query 'DelegationSet.NameServers' --output json"

  exit 0
fi

# Create the hosted zone
echo "Creating Hosted Zone for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "$(date +%s)" --query 'HostedZone.Id' --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Failed to create hosted zone."
  exit 1
fi

echo "Hosted Zone ID: $HOSTED_ZONE_ID"

# Retrieve NS records
echo "Retrieving NS records..."
NS_RECORDS=$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'DelegationSet.NameServers' --output json)

echo "==========================="
echo "Please configure the following NS records with your domain registrar:"
echo "${DOMAIN}.  IN  NS  $NS_RECORDS"
echo "==========================="

# ===============================
# Add NS records to the parent domain (Z104432328G24Z3B7DMOB)
# ===============================

PARENT_HOSTED_ZONE_ID="Z104432328G24Z3B7DMOB"

# Format NS records
NS_RECORDS_JSON=$(echo "$NS_RECORDS" | jq -c '[.[] | { "Value": . }]')

echo "Adding NS records to the parent domain's hosted zone..."
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
# Add NS records to the parent domain in AWS Route 53
# ===============================

echo "==============================="
echo "If using Route 53, execute the following command:"
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

