#!/bin/bash

# ===============================
# SSL証明書の検証完了を待機 (Dry-Run対応)
# ===============================

# 変数定義
CERT_ARN=$1
DRY_RUN=$2  # --dry-run オプション
AWS_REGION="us-east-1"  # CloudFront 用なら us-east-1

if [ -z "$CERT_ARN" ]; then
  echo "Usage: $0 <certificate_arn> [--dry-run]"
  exit 1
fi

# Dry-Run モードなら、すべての AWS コマンドを表示して終了
if [ "$DRY_RUN" == "--dry-run" ]; then
  echo "[Dry-Run] 証明書の検証ステータスを確認するコマンド:"
  echo "aws acm describe-certificate --certificate-arn $CERT_ARN --region $AWS_REGION --query 'Certificate.Status' --output text"
  exit 0
fi

# ===============================
# SSL証明書の検証完了を待機 (本番実行)
# ===============================
echo "Waiting for SSL certificate to be issued..."
while true; do
  CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION" --query 'Certificate.Status' --output text)

  echo "Current certificate status: $CERT_STATUS"

  if [ "$CERT_STATUS" == "ISSUED" ]; then
    echo "SSL証明書が正常に発行されました！ 🎉"
    break
  elif [ "$CERT_STATUS" == "FAILED" ]; then
    echo "Error: SSL証明書の発行に失敗しました。"
    exit 1
  fi

  echo "まだ発行中です... 1分後に再確認します。"
  sleep 60
done

