#!/bin/bash

# ===============================
# 既存 ALB に SSL 証明書を適用 & Route 53 に A レコードを追加 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
ALB_NAME=$2
DRY_RUN=$3  # --dry-run オプション
AWS_REGION="ap-southeast-1"  # 必要なら変更

if [ -z "$DOMAIN" ] || [ -z "$ALB_NAME" ]; then
  echo "Usage: $0 <domain> <alb_name> [--dry-run]"
  exit 1
fi

# Dry-Run モードなら、すべてのコマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] Route 53 の Hosted Zone ID を取得するコマンド:"
  echo "aws route53 list-hosted-zones-by-name --dns-name \"$DOMAIN\" --query \"HostedZones[0].Id\" --output text"

  echo "[Dry-Run] ACM 証明書の ARN を取得するコマンド:"
  echo "aws acm list-certificates --region $AWS_REGION --query \"CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]\" --output text"

  echo "[Dry-Run] 既存 ALB の ARN を取得するコマンド:"
  echo "aws elbv2 describe-load-balancers --region $AWS_REGION --query \"LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn | [0]\" --output text"

  echo "[Dry-Run] ALB の DNS 名と Hosted Zone ID を取得するコマンド:"
  echo "aws elbv2 describe-load-balancers --load-balancer-arns <ALB_ARN> --query \"LoadBalancers[0].DNSName\" --output text"
  echo "aws elbv2 describe-load-balancers --load-balancer-arns <ALB_ARN> --query \"LoadBalancers[0].CanonicalHostedZoneId\" --output text"

  echo "[Dry-Run] 既存の HTTPS リスナーを取得するコマンド:"
  echo "aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query \"Listeners[?Protocol=='HTTPS'].ListenerArn | [0]\" --output text"

  echo "[Dry-Run] ACM 証明書の ARN を適用するコマンド:"
  echo "aws elbv2 modify-listener --listener-arn <LISTENER_ARN> --certificates CertificateArn=<CERT_ARN> --region $AWS_REGION"

  echo "[Dry-Run] Route 53 に ALB の A レコードを追加するコマンド:"
  echo "aws route53 change-resource-record-sets --hosted-zone-id <HOSTED_ZONE_ID> --change-batch '{\"Changes\":[{\"Action\":\"CREATE\",\"ResourceRecordSet\":{\"Name\":\"$DOMAIN\",\"Type\":\"A\",\"AliasTarget\":{\"HostedZoneId\":\"<ALB_HOSTED_ZONE_ID>\",\"DNSName\":\"<ALB_DNS_NAME>\",\"EvaluateTargetHealth\":true}}}]}'"

  exit 0
fi

# ===== 本番実行 =====

# Route 53 の Hosted Zone ID を取得
echo "Retrieving Hosted Zone ID for $DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted Zone ID not found for $DOMAIN"
  exit 1
fi

echo "Using Hosted Zone ID: $HOSTED_ZONE_ID"

# ACM 証明書の ARN を取得
echo "Retrieving ACM Certificate ARN for $DOMAIN..."
CERT_ARN=$(aws acm list-certificates --region $AWS_REGION --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ]; then
  echo "Error: SSL certificate ARN not found for $DOMAIN"
  exit 1
fi

echo "Using Certificate ARN: $CERT_ARN"

# 既存 ALB の ARN を取得
echo "Retrieving ALB ARN for ALB named $ALB_NAME..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn | [0]" --output text)

if [ -z "$ALB_ARN" ]; then
  echo "Error: ALB $ALB_NAME not found"
  exit 1
fi

echo "Using ALB ARN: $ALB_ARN"

# ALB の DNS 名と Hosted Zone ID を取得
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query "LoadBalancers[0].DNSName" --output text)
ALB_HOSTED_ZONE_ID=$(aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query "LoadBalancers[0].CanonicalHostedZoneId" --output text)

if [ -z "$ALB_DNS_NAME" ] || [ -z "$ALB_HOSTED_ZONE_ID" ]; then
  echo "Error: Failed to retrieve ALB DNS Name or Hosted Zone ID"
  exit 1
fi

echo "ALB DNS Name: $ALB_DNS_NAME"
echo "ALB Hosted Zone ID: $ALB_HOSTED_ZONE_ID"

# 既存の HTTPS リスナーを取得
echo "Retrieving existing HTTPS listener for ALB..."
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[?Protocol=='HTTPS'].ListenerArn | [0]" --output text)

if [ -z "$LISTENER_ARN" ]; then
  echo "Error: No existing HTTPS listener found for ALB $ALB_NAME"
  exit 1
fi

echo "Using existing HTTPS Listener ARN: $LISTENER_ARN"

# 既存の HTTPS リスナーに新しい証明書を適用
echo "Applying SSL Certificate to ALB HTTPS Listener..."
aws elbv2 modify-listener --listener-arn $LISTENER_ARN --certificates CertificateArn=$CERT_ARN --region $AWS_REGION

echo "SSL Certificate applied successfully."

# Route 53 に A レコードを追加
echo "Adding ALB A record to Route 53..."
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "'"$DOMAIN"'",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "'"$ALB_HOSTED_ZONE_ID"'",
        "DNSName": "'"$ALB_DNS_NAME"'",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'

echo "ALB A record added for $DOMAIN."

