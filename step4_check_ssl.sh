#!/bin/bash

# ===============================
# Check SSL Certificate Issuance Status (Dry-Run Supported)
# ===============================

# Variable Definitions
DOMAIN=$1
DRY_RUN=$2  # --dry-run option
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# If Dry-Run mode is enabled, display AWS commands and exit
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Command to retrieve certificate ARN:"
  echo "aws acm list-certificates --region $AWS_REGION --query \"CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]\" --output text"

  echo "[Dry-Run] Command to check certificate validation status:"
  echo "aws acm describe-certificate --certificate-arn <CERT_ARN> --region $AWS_REGION --query 'Certificate.Status' --output text"
  exit 0
fi

# ===============================
# Retrieve SSL Certificate ARN
# ===============================
echo "Retrieving SSL certificate ARN for $DOMAIN..."
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "Error: SSL certificate not found. It may not have been requested or is not registered in ACM."
  exit 1
fi

echo "Found Certificate ARN: $CERT_ARN"

# ===============================
# Check SSL Certificate Status
# ===============================

echo "Checking SSL certificate status for $CERT_ARN..."

CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.Status' --output text)

echo "Current certificate status: $CERT_STATUS"

if [ "$CERT_STATUS" == "ISSUED" ]; then
  echo "SSL certificate has been successfully issued!"
  exit 0
elif [ "$CERT_STATUS" == "FAILED" ]; then
  echo "Error: SSL certificate issuance failed."
  exit 1
else
  echo "SSL certificate has not been issued yet (Current status: $CERT_STATUS)."
  echo "Please try again later."
  exit 2
fi

