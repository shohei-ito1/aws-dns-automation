#!/bin/bash

# ホストゾーンの作成
sh ./step1_create_hosted_zone.sh sub2 example.com

# SSL 証明書の設定
sh ./step2_setup_ssl.sh sub2 example.com

# メール送信設定
sh ./step3_setup_email.sh sub2 example.com

