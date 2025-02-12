#!/bin/bash

# ===============================
# Attach New SSL Certificate to ALB & Preserve Existing Certificates
# ===============================

DOMAIN=$1
ALB_NAME=$2
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ] || [ -z "$ALB_NAME" ]; then
  echo "Usage: $0 <domain> <alb_name>"
  exit 1
fi

# Retrieve Route 53 Hosted Zone ID
echo "Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --region "$AWS_REGION" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

# Retrieve ACM Certificate ARN
echo "Retrieving ACM Certificate ARN for $DOMAIN..."
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ]; then
  echo "Error: SSL certificate ARN not found for $DOMAIN"
  exit 1
fi

echo "Using Certificate ARN: $CERT_ARN"

# Retrieve ALB ARN
echo "Retrieving ALB ARN for ALB named $ALB_NAME..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn | [0]" --output text)

if [ -z "$ALB_ARN" ]; then
  echo "Error: ALB $ALB_NAME not found"
  exit 1
fi

echo "Using ALB ARN: $ALB_ARN"

# Retrieve ALB DNS Name and Hosted Zone ID
echo "Retrieving ALB DNS Name and Hosted Zone ID..."
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query "LoadBalancers[0].DNSName" --output text)
ALB_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query "LoadBalancers[0].CanonicalHostedZoneId" --output text)

if [ -z "$ALB_DNS_NAME" ] || [ -z "$ALB_HOSTED_ZONE_ID" ]; then
  echo "Error: ALB DNS Name or Hosted Zone ID could not be retrieved. Please verify the ALB ARN."
  exit 1
fi

echo "ALB DNS Name: $ALB_DNS_NAME"
echo "ALB Hosted Zone ID: $ALB_HOSTED_ZONE_ID"

# Retrieve Existing HTTPS Listener
echo "Retrieving existing HTTPS listener for ALB..."
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query "Listeners[?Protocol=='HTTPS'].ListenerArn | [0]" --output text)

if [ -z "$LISTENER_ARN" ]; then
  echo "Error: No existing HTTPS listener found for ALB $ALB_NAME"
  exit 1
fi

echo "Using existing HTTPS Listener ARN: $LISTENER_ARN"

# Retrieve Existing Certificates
echo "Retrieving existing certificates on the ALB listener..."
EXISTING_CERTS=$(aws elbv2 describe-listener-certificates --listener-arn "$LISTENER_ARN" --region "$AWS_REGION" --query "Certificates[*].CertificateArn" --output json)

if [ -z "$EXISTING_CERTS" ]; then
  echo "No existing certificates found, adding the first certificate."
else
  echo "Existing Certificates: $EXISTING_CERTS"
fi

# Add New SSL Certificate Without Removing Existing Ones
echo "Attaching new SSL certificate while preserving existing ones..."
aws elbv2 add-listener-certificates --listener-arn "$LISTENER_ARN" --certificates CertificateArn="$CERT_ARN" --region "$AWS_REGION"

if [ $? -ne 0 ]; then
  echo "Error: Failed to attach SSL certificate to ALB listener."
  exit 1
fi

echo "New SSL Certificate attached successfully using SNI."

# Add A Record to Route 53
echo "Adding ALB A record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --region "$AWS_REGION" --change-batch "{
  \"Changes\": [{
    \"Action\": \"UPSERT\",
    \"ResourceRecordSet\": {
      \"Name\": \"$DOMAIN\",
      \"Type\": \"A\",
      \"AliasTarget\": {
        \"HostedZoneId\": \"$ALB_HOSTED_ZONE_ID\",
        \"DNSName\": \"$ALB_DNS_NAME\",
        \"EvaluateTargetHealth\": true
      }
    }
  }]
}"

echo "ALB A record added for $DOMAIN."

