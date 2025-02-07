#!/bin/bash

# ===============================
# 全ステップの Dry-Run 実行スクリプト
# ===============================

# 変数定義
SUBDOMAIN="sub2"
DOMAIN="example.com"
FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"
DRY_RUN="--dry-run"

echo "==============================="
echo " Dry-Run モードで全ステップを実行します"
echo " 対象ドメイン: $FULL_DOMAIN"
echo "==============================="

# Step 1: ホストゾーンの作成
sh ./step1_create_hosted_zone.sh $FULL_DOMAIN $DRY_RUN

# Step 2: SSL 証明書の設定
sh ./step2_request_ssl.sh $FULL_DOMAIN $DRY_RUN

# Step 3: SSL 証明書の検証
sh ./step3_check_ssl.sh "<CERT_ARN>" $DRY_RUN

# Step 4: メール送信設定
sh ./step4_setup_email.sh $FULL_DOMAIN $DRY_RUN

echo "==============================="
echo " Dry-Run の全ステップが完了しました"
echo "==============================="

