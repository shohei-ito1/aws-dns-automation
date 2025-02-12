#!/bin/bash

# ===============================
# Check SSL Certificates Attached to ALB
# ===============================

ALB_NAME=$1
AWS_REGION="ap-southeast-1"

if [ -z "$ALB_NAME" ]; then
  echo "Usage: $0 <alb_name>"
  exit 1
fi

# Retrieve ALB ARN
echo "Retrieving ALB ARN for ALB named $ALB_NAME..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn | [0]" --output text)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
  echo "Error: ALB $ALB_NAME not found"
  exit 1
fi

echo "Using ALB ARN: $ALB_ARN"

# Retrieve ALB Listener ARN
echo "Retrieving existing HTTPS listener for ALB..."
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query "Listeners[?Protocol=='HTTPS'].ListenerArn | [0]" --output text)

if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" == "None" ]; then
  echo "Error: No HTTPS listener found for ALB $ALB_NAME"
  exit 1
fi

echo "Using HTTPS Listener ARN: $LISTENER_ARN"

# Retrieve Attached SSL Certificates
echo "Retrieving SSL certificates attached to the ALB listener..."
CERT_ARNS=$(aws elbv2 describe-listener-certificates --listener-arn "$LISTENER_ARN" --region "$AWS_REGION" --query "Certificates[*].CertificateArn" --output json)

if [ -z "$CERT_ARNS" ] || [ "$CERT_ARNS" == "[]" ]; then
  echo "No SSL certificates found on the ALB listener."
  exit 1
fi

echo "Attached SSL Certificates:"
echo "$CERT_ARNS" | jq -r '.[]'

# Fetch and Display Certificate Details from ACM
echo "Fetching certificate details from AWS ACM..."
for CERT_ARN in $(echo "$CERT_ARNS" | jq -r '.[]'); do
  DOMAIN_NAME=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query "Certificate.DomainName" --output text)
  SAN_NAMES=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query "Certificate.SubjectAlternativeNames" --output json)
  STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query "Certificate.Status" --output text)
  
  echo "------------------------------------"
  echo "Certificate ARN: $CERT_ARN"
  echo "Primary Domain: $DOMAIN_NAME"
  echo "SAN Domains: $SAN_NAMES"
  echo "Status: $STATUS"
  echo "------------------------------------"
done

