# Security Policy

## Supported Versions

Only the latest release of this image is maintained. Its rolling tags
(`8.4-fpm`, `8.4.27-fpm`...) are rebuilt within a day of every update of the
official PHP images, which is how PHP and Debian security fixes reach them.
The `-vX.Y.Z` tags are never rebuilt.

| PHP branch | Supported          |
|------------|--------------------|
| 8.2 – 8.5  | :white_check_mark: |
| 8.1 and older | :x: no fixes upstream, no images here |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please DO NOT file a public issue for security vulnerabilities.**

Instead, please send an email to: **<dev@frugan.it>**

Include the following information:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Any suggested fixes (if available)

Vulnerabilities of PHP itself go to the
[PHP security team](https://www.php.net/manual/en/security.php), those of
the official images to [docker-library/php](https://github.com/docker-library/php).

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt within 48 hours
2. **Assessment**: We will assess the vulnerability within 5 business days
3. **Resolution**: We will work to resolve critical issues within 30 days
4. **Disclosure**: We will coordinate with you on responsible disclosure

### Responsible Disclosure

We believe in responsible disclosure. We ask that you:

- Give us reasonable time to investigate and fix the issue
- Do not publicly disclose the vulnerability until we've had a chance to fix it
- Do not exploit the vulnerability for malicious purposes

### Security Best Practices

When running these images:

1. **Rolling tags**: run `8.4-fpm`, not a `-v` tag, and pull regularly
   (`docker compose pull && docker compose up -d`): a PHP security release is
   only applied once the container is recreated
2. **Secrets**: pass the SMTP password through `MSMTP_PASSWORD_FILE` and a
   Docker secret. With `clear_env = no`, every other variable of the container
   is visible to PHP code, `phpinfo()` included
3. **Privileges**: the FPM workers run as `www-data`. For containers that need
   no root at all, run them rootless (`user:`), optionally with
   `read_only: true`
4. **Development images**: never run the `-dev` tags in production

## Security Contact

For security-related questions or concerns:

- Email: <dev@frugan.it>
- GitHub: [@frugan-dev](https://github.com/frugan-dev)

## Acknowledgments

We appreciate the security research community's efforts in responsibly disclosing vulnerabilities. Security researchers who help us improve this project will be acknowledged in our security advisories (with their permission).
