#!/bin/bash

# ===============================
# SSL証明書の発行ステータス確認 (Dry-Run対応)
# ===============================

# 変数定義
DOMAIN=$1
DRY_RUN=$2  # --dry-run オプション
AWS_REGION="ap-southeast-1"

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain> [--dry-run]"
  exit 1
fi

# Dry-Run モードなら、AWS コマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] 証明書の ARN を取得するコマンド:"
  echo "aws acm list-certificates --region $AWS_REGION --query \"CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]\" --output text"

  echo "[Dry-Run] 証明書の検証ステータスを確認するコマンド:"
  echo "aws acm describe-certificate --certificate-arn <CERT_ARN> --region $AWS_REGION --query 'Certificate.Status' --output text"
  exit 0
fi

# ===============================
# SSL証明書の ARN を取得
# ===============================
echo "Retrieving SSL certificate ARN for $DOMAIN..."
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  echo "❌ Error: SSL証明書が見つかりません。まだリクエストされていないか、ACM に登録されていません。"
  exit 1
fi

echo "Found Certificate ARN: $CERT_ARN"

# ===============================
# SSL証明書のステータス確認
# ===============================

echo "Checking SSL certificate status for $CERT_ARN..."

CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.Status' --output text)

echo "Current certificate status: $CERT_STATUS"

if [ "$CERT_STATUS" == "ISSUED" ]; then
  echo "✅ SSL証明書は正常に発行されています！ 🎉"
  exit 0
elif [ "$CERT_STATUS" == "FAILED" ]; then
  echo "❌ Error: SSL証明書の発行に失敗しました。"
  exit 1
else
  echo "⏳ まだSSL証明書が発行されていません (現在のステータス: $CERT_STATUS)。"
  echo "後で再度実行してください。"
  exit 2
fi

