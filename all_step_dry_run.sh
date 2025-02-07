#!/bin/bash

echo "==============================="
echo " Dry-Run モードで全ステップを実行します"
echo " 対象ドメイン: sub2.example.com"
echo "==============================="

echo "Step 1: ホストゾーンの作成"
sh ./step1_create_hosted_zone.sh sub2.example.com --dry-run

echo "Step 2: SSL 証明書のリクエスト"
sh ./step2_request_ssl.sh sub2.example.com --dry-run

# `step2_request_ssl.sh` で出力される Certificate ARN を取得するためのダミー値
CERT_ARN="<CERT_ARN>"

echo "Step 3: ALBへの紐付け"
sh ./step3_attach_alb.sh sub2.example.com my-existing-alb --dry-run


echo "Step 4: SSL 証明書の検証"
sh ./step4_check_ssl.sh "$CERT_ARN" --dry-run

echo "Step 5: メール送信設定"
sh ./step5_setup_email.sh sub2.example.com --dry-run

echo "==============================="
echo " Dry-Run の全ステップが完了しました"
echo "==============================="

