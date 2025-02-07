#!/bin/bash

echo "========== START step 1  =========="
sh ./step1_create_hosted_zone.sh q-test.dev-hinode-labo.com --dry-run
echo "========== START step 2  =========="
sh ./step2_request_ssl.sh        q-test.dev-hinode-labo.com --dry-run
echo "========== START step 3  =========="
sh ./step3_check_ssl.sh          q-test.dev-hinode-labo.com --dry-run
echo "========== START step 4  =========="
sh ./step4_attach_alb.sh         q-test.dev-hinode-labo.com my-existing-alb --dry-run
echo "========== START step 5  =========="
sh ./step5_setup_email.sh        q-test.dev-hinode-labo.com --dry-run
echo "========== FINISH =========="
