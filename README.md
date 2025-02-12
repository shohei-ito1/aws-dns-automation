# aws-dns-automation

## Overview
This project automates the setup and management of AWS Route 53 DNS, SSL certificates, and ALB configuration for newly acquired domains.
It ensures that new domains and subdomains are independently managed without affecting existing parent domains or subdomains.

## Prerequisites
Before executing the scripts, ensure that:
- You have AWS CLI installed and configured with necessary permissions.
- The domain's NS records are properly configured with the registrar.
- AWS Route 53, ACM, ALB, and SES are set up in the AWS environment.

## Execution Steps

```bash
sh step1_create_hosted_zone.sh q-test50.dev-hinode-labo.com
sh step2_request_ssl.sh q-test50.dev-hinode-labo.com
sh step3_register_dns.sh q-test50.dev-hinode-labo.com
sh step4_check_ssl.sh q-test50.dev-hinode-labo.com
sh step5_attach_alb.sh q-test50.dev-hinode-labo.com q-dns-test
sh step6_setup_email.sh q-test50.dev-hinode-labo.com
```

Step 1: Create a Hosted Zone
Creates an AWS Route 53 hosted zone for the specified domain.

Step 2: Request an SSL Certificate
Requests a SAN SSL certificate in AWS ACM with DNS validation.

Step 3: Register DNS Records for SSL Validation
Retrieves and registers DNS records required for SSL validation.

Step 4: Check SSL Certificate Status
Verifies the SSL certificate issuance status.

Step 5: Attach SSL Certificate to ALB
Associates the issued SSL certificate with an existing AWS ALB and configures Route 53 A records.

Step 6: Configure Email DNS Settings
Sets up DKIM, SPF, DMARC, and MX records for email services via AWS SES.

## Features

Independent DNS Management: New subdomains are managed separately without affecting existing domains.
Secure HTTPS Communication: Uses SAN and SNI to efficiently manage multiple domains under a single ALB.
Email Sending Support: Configures SES-related DNS records for email verification and security.
Scalable: Supports an unlimited number of domains while keeping costs practical.


## Notes

Ensure that subdomain delegation (NS record updates) is completed by the parent domain administrator.
The ALB must be pre-configured before running step 5.
Email-related DNS changes (Step 6) may take time to propagate.


## SSL and HTTPS Configuration
- The web service communicates over HTTPS via AWS ALB, ensuring secure access.
- A **SAN (Subject Alternative Name) SSL certificate** is used to consolidate multiple domains and subdomains under a single certificate.
- The SAN certificate is linked to the ALB, enabling centralized SSL management.
- **SNI (Server Name Indication)** is leveraged to attach multiple SAN certificates to the same ALB, allowing efficient handling of numerous domains.
- Both **SAN and SNI** are utilized together to scale SSL management.
- The number of domains that can be managed in AWS is subject to theoretical limits:
  - The **maximum number of domains per SAN certificate**.
  - The **number of SAN certificates that can be attached to an ALB via SNI**.
  - The total manageable domains is determined by the product of these two constraints.


## Useful Commands

```bash

dig NS dev-hinode-labo.com +short|sort

```
