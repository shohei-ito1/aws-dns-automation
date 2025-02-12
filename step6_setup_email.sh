#!/bin/bash

# ===============================
# Step6: Configure Email Sending DNS Settings in AWS Route 53 (Fully Automated)
# ===============================

# Variable Definitions
DOMAIN=$1
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

# ===== Execute in Production Mode =====

# Verify domain identity in SES
echo "Verifying domain identity with SES..."
IDENTITY_VERIFICATION=$(aws ses verify-domain-identity --domain "$DOMAIN" --region "$AWS_REGION")

if [ $? -ne 0 ]; then
  echo "Error: Failed to verify domain identity for $DOMAIN"
  exit 1
fi

echo "Domain identity verification request sent."

# Retrieve DKIM records
echo "Retrieving DKIM records..."
DKIM_RECORDS=$(aws ses verify-domain-dkim --domain "$DOMAIN" --query 'DkimTokens' --output json --region "$AWS_REGION")

if [ $? -ne 0 ] || [ -z "$DKIM_RECORDS" ]; then
  echo "Error: Failed to retrieve DKIM tokens for $DOMAIN"
  exit 1
fi

DKIM1=$(echo "$DKIM_RECORDS" | jq -r '.[0]')
DKIM2=$(echo "$DKIM_RECORDS" | jq -r '.[1]')
DKIM3=$(echo "$DKIM_RECORDS" | jq -r '.[2]')

echo "DKIM records retrieved."

# Retrieve Hosted Zone ID from Route 53
echo "Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text --region "$AWS_REGION")

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

# Add DKIM, SPF, DMARC, and MX records to Route 53
echo "Adding DKIM, SPF, DMARC, and MX records to Route 53..."
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
  echo "Error: Failed to add DNS records to Route 53"
  exit 1
fi

echo "SPF, DMARC, MX, and DKIM records added to Route 53."
