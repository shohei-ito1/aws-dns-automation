# aws-dns-automation

## example.com の場合
## sub.example.com に変更も可能

```sh
# AWS Route 53 に Hosted Zone を作成
sh step1_create_hosted_zone.sh example.com

#################
# 上記が完了したら管理者にNSレコードを変更依頼
#################

# SSL証明書をリクエスト
sh step2_request_ssl.sh example.com

# SSL証明書の発行状況を確認
sh step3_check_ssl.sh <CERT_ARN>

# メール送信用のDNS設定を追加
sh step4_setup_email.sh example.com
```
