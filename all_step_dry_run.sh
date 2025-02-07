#!/bin/bash
echo "==============================="
echo " Dry-Run モードで全ステップを実行します"
echo "==============================="
sh ./step1_create_hosted_zone.sh sub2.example.com --dry-run
sh ./step2_request_ssl.sh sub2.example.com --dry-run

# `step2_request_ssl.sh` で出力される Certificate ARN を取得するためのダミー値
CERT_ARN="<CERT_ARN>"

sh ./step3_check_ssl.sh "$CERT_ARN" --dry-run
sh ./step4_attach_alb.sh sub2.example.com my-existing-alb --dry-run
sh ./step5_setup_email.sh sub2.example.com --dry-run

echo "==============================="
echo " Dry-Run の全ステップが完了しました"
echo "==============================="
