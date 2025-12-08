# Security Quick Reference Card

## 🔐 Credentials

### First Run
```bash
# Random password auto-generated
docker-compose up
docker logs dns-stack | grep "Password:"
```

### Custom Password
```bash
# docker-compose.yml
environment:
  ADGUARD_PASSWORD: "YourSecurePassword123"
```

### Find Password
```bash
# Method 1: Logs
docker logs dns-stack | grep -A 5 "Credentials:"

# Method 2: File
docker exec dns-stack cat /config/AdGuardHome/.credentials
```

### Reset Password
```bash
docker exec dns-stack rm /config/AdGuardHome/.credentials
docker restart dns-stack
# New password generated
```

---

## 🛡️ Pre-commit Hooks

### Setup (One Time)
```bash
pip install pre-commit
pre-commit install
```

### Usage
```bash
# Automatic on commit
git commit -m "Your changes"

# Manual check
pre-commit run --all-files

# Skip (emergency only!)
git commit --no-verify
```

### What It Checks
- ✅ Shell scripts (shellcheck)
- ✅ Dockerfile (hadolint)
- ✅ Secrets detection
- ✅ YAML validation
- ✅ Trailing whitespace
- ✅ Markdown formatting

---

## 🔍 Security Scanning

### Where to Check
1. **GitHub Actions** → CI/CD workflow
2. **Security Tab** → Vulnerability reports
3. **Pull Requests** → Automatic comments

### Manual Scan
```bash
# Install Trivy
brew install trivy  # macOS
# or: apt-get install trivy  # Linux

# Scan image
trivy image dns-stack:latest
```

### What It Scans
- 🔍 OS vulnerabilities
- 🔍 Package vulnerabilities
- 🔍 Secrets in code (Gitleaks)
- 🔍 Configuration issues

---

## 🚨 Common Issues

### "Can't login to AdGuard"
```bash
# Check password
docker logs dns-stack | grep "Password:"

# Or check file
docker exec dns-stack cat /config/AdGuardHome/.credentials
```

### "Pre-commit hooks fail"
```bash
# Update hooks
pre-commit autoupdate

# Reinstall
pre-commit clean
pre-commit install
```

### "CI fails on vulnerabilities"
1. Check Security tab for details
2. Wait for Renovate to create update PR
3. Or suppress false positives in `.trivyignore`

---

## ✅ Security Checklist

### First Deployment
- [ ] Set ADGUARD_PASSWORD environment variable
- [ ] Save generated credentials securely
- [ ] Install pre-commit hooks
- [ ] Enable GitHub security features
- [ ] Review initial Trivy scan

### Ongoing
- [ ] Check Security tab weekly
- [ ] Review Renovate PRs promptly
- [ ] Update dependencies monthly
- [ ] Rotate credentials quarterly
- [ ] Review logs for suspicious activity

---

## 📚 Full Documentation

- [SECURITY_IMPROVEMENTS.md](../SECURITY_IMPROVEMENTS.md) - Complete implementation details
- [SETUP_PRECOMMIT.md](SETUP_PRECOMMIT.md) - Pre-commit setup guide
- [README.md](../README.md) - General documentation
