#!/bin/bash

# ===============================
# Register SSL Certificate DNS Validation CNAME
# ===============================

DOMAIN=$1
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "error=missing_domain_argument"
  exit 1
fi

# Retrieve Route 53 Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  echo "error=hosted_zone_not_found, domain=$DOMAIN"
  exit 1
fi

echo "hosted_zone_id=$HOSTED_ZONE_ID"

# Retrieve ACM Certificate ARN
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "error=certificate_not_found, domain=$DOMAIN"
  exit 1
fi

echo "certificate_arn=$CERT_ARN"

# Retrieve CNAME records for SAN validation
CERT_VALIDATION_RECORDS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.DomainValidationOptions[*].ResourceRecord' --output json)

for record in $(echo "$CERT_VALIDATION_RECORDS" | jq -c '.[]'); do
  VALIDATION_NAME=$(echo "$record" | jq -r '.Name')
  VALIDATION_VALUE=$(echo "$record" | jq -r '.Value')

  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$VALIDATION_NAME\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$VALIDATION_VALUE\"}]
      }
    }]
  }"
done

if [ -z "$VALIDATION_NAME" ] || [ -z "$VALIDATION_VALUE" ]; then
  echo "error=failed_to_retrieve_cname_records, certificate_arn=$CERT_ARN"
  exit 1
fi

echo "validation_name=$VALIDATION_NAME"
echo "validation_value=$VALIDATION_VALUE"

# Add CNAME record to Route 53
echo "Adding SSL validation record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "'"$VALIDATION_NAME"'",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "'"$VALIDATION_VALUE"'"}]
    }
  }]
}'

if [ $? -ne 0 ]; then
  echo "error=failed_to_add_cname_to_route53"
  exit 1
fi

echo "SSL validation record added successfully."

