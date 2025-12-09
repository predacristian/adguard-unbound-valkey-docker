# DNS Stack

![CI/CD Status](https://img.shields.io/badge/CI%2FCD-Optimized-brightgreen)
![Security Scanning](https://img.shields.io/badge/Security-Trivy%20%2B%20Gitleaks-blue)
![Pre-commit Hooks](https://img.shields.io/badge/Pre--commit-Enabled-orange)
![Semantic Release](https://img.shields.io/badge/semantic--release-automated-e10079)
![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)

A secure, containerized DNS solution combining Unbound DNS, AdGuard Home, and Valkey for efficient DNS resolution, caching, and ad blocking.

## Components

- **Unbound DNS**: Validating, recursive, and caching DNS resolver
- **AdGuard Home**: Network-wide ads & tracking blocking DNS server
- **Valkey**: Lightweight in-memory cache for Unbound DNS

## Features

- 🔒 **Automatic credential generation** - Random passwords on first run
- 🧪 **Comprehensive testing** - Smoke, integration, and BATS tests
- 🛡️ **Security scanning** - Trivy vulnerability + Gitleaks secret detection
- ⚡ **Optimized CI/CD** - Parallel multi-arch builds (40-84% faster)
- 🪝 **Pre-commit hooks** - Automated code quality checks
- 🤖 **Automated releases** - Semantic versioning with auto-generated changelogs
- 🔄 **Dependency automation** - Renovate auto-merges safe updates
- 🐳 **Docker Compose** - Simple orchestration with Makefile
- 📦 **DNS caching** - Valkey backend with Unix socket
- 🚫 **Ad blocking** - Custom filtering through AdGuard Home
- 🔐 **DNS over TLS (DoT)** - Secure DNS resolution
- 🎯 **DNSSEC validation** - Enhanced security

## Quick Start 🚀

### Using Docker Compose (Recommended)

```bash
# Clone and start
git clone <repo-url>
cd adguard-unbound-valkey-docker
make up

# View logs and credentials
make logs

# Run tests
make test

# Stop
make down
```

### Using Docker

```bash
# Use latest version
docker run -d \
  --name dns-stack \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 853:853/tcp \
  -p 3000:3000/tcp \
  -e ADGUARD_PASSWORD=YourSecurePassword123 \
  -v ./config:/config \
  ghcr.io/yourusername/repo:latest

# Pin to specific version (recommended for production)
docker run -d \
  --name dns-stack \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 853:853/tcp \
  -p 3000:3000/tcp \
  -e ADGUARD_PASSWORD=YourSecurePassword123 \
  -v ./config:/config \
  ghcr.io/yourusername/repo:v1.2.3
```

> **Note:** Replace `yourusername/repo` with your actual repository path. See [releases](https://github.com/yourusername/repo/releases) for available versions.

## Security & Access 🔐

### AdGuard Home Web Interface

**Access:** `http://localhost:3000`

**First Run Credentials:**
- ✅ **Random password automatically generated**
- ✅ Displayed in container logs
- ✅ Saved to `/config/AdGuardHome/.credentials`

```bash
# View credentials
docker logs dns-stack | grep "Password:"
# or
make logs
```

**Custom Password (Recommended):**
```yaml
# docker-compose.yml
environment:
  ADGUARD_PASSWORD: "YourSecurePassword123"
  ADGUARD_USERNAME: "admin"  # optional
```

⚠️ **Security:** Random passwords are generated if `ADGUARD_PASSWORD` is not set. Default `admin/admin` only used as fallback.

## Default Ports

| Port | Protocol | Service |
|------|----------|---------|
| 53 | TCP/UDP | DNS |
| 853 | TCP | DNS-over-TLS |
| 3000 | TCP | AdGuard Home UI |
| 8443 | TCP | HTTPS (when TLS enabled) |

## Configuration ⚙️

### Directory Structure

```
/config/
├── unbound/         # Unbound DNS configuration
├── AdGuardHome/     # AdGuard Home configuration
└── valkey/          # Valkey cache configuration
```

Default configurations are copied on first run.

### Environment Variables

**Runtime:**
- `ADGUARD_PASSWORD` - Custom password for AdGuard Home
- `ADGUARD_USERNAME` - Custom username (default: `admin`)
- `TZ` - Timezone (default: `UTC`)

**Build Arguments:**
- `ALPINE_VERSION` - Alpine Linux version (default: `3.23.0`)
- `UNBOUND_VERSION` - Unbound DNS version (default: `1.23.1`)
- `ADGUARD_VERSION` - AdGuard Home version (default: `v0.107.71`)
- `VALKEY_VERSION` - Valkey version (default: `9.0.0`)

## Testing 🧪

Comprehensive test suite with smoke, integration, and structured BATS tests:

```bash
make test              # Full test suite
make test-smoke        # Quick smoke tests (Unbound, Valkey, AdGuard)
make test-integration  # Integration tests (caching, E2E, ad blocking)
make test-bats         # BATS structured tests (15 tests)
make test-cache        # Cache integration test
make test-e2e          # End-to-end query path
```

### Test Coverage

- ✅ Service health checks
- ✅ DNS resolution (A, AAAA, MX, TXT records)
- ✅ Unbound → Valkey caching via Unix socket
- ✅ AdGuard → Unbound forwarding
- ✅ Ad blocking functionality
- ✅ DNSSEC validation
- ✅ DNS-over-TLS configuration
- ✅ Cache performance
- ✅ Reverse DNS lookups

See [tests/README.md](tests/README.md) for details.

## Development 🛠️

### Building Locally

```bash
docker build -t dns-stack .
# or
make build
```

### Makefile Commands

```bash
make up              # Start DNS stack
make down            # Stop DNS stack
make logs            # View logs (follow mode)
make build           # Build Docker image
make test            # Run all tests
make clean           # Remove containers and volumes
make status          # Show container status
make health          # Check health status
make shell           # Open shell in container
```

### Pre-commit Hooks

Automated code quality checks on every commit:

```bash
# One-time setup
pip install pre-commit
pre-commit install

# Manual run
pre-commit run --all-files
```

**Checks:**
- ShellCheck (shell script linting)
- Hadolint (Dockerfile linting)
- detect-secrets (secret scanning)
- YAML validation
- Markdown formatting
- Trailing whitespace

See [.github/SETUP_PRECOMMIT.md](.github/SETUP_PRECOMMIT.md) for setup guide.

### Security Scanning

Automated security scanning on every push and daily:

**Trivy** - Container vulnerability scanning
- OS package vulnerabilities
- Application dependencies
- CRITICAL/HIGH/MEDIUM severity
- Results in GitHub Security tab

**Gitleaks** - Secret detection
- Scans entire git history
- API keys, passwords, tokens
- Private keys, credentials

View reports: **Repository → Security tab**

## CI/CD ⚡

Optimized multi-architecture build pipeline:

### Performance

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Pull Request | 45 min | 7 min | **84% faster** |
| Push to main (cold) | 47 min | 28 min | **40% faster** |
| Push to main (warm) | 39 min | 15 min | **62% faster** |

### Features

- ⚡ **Parallel architecture builds** (amd64 + arm64 simultaneously)
- 🎯 **Fast testing** (amd64 only - 5-7 min)
- 💾 **Dual-layer caching** (Registry + GitHub Actions)
- 🎨 **Smart triggers** (skip docs-only changes)
- 🏗️ **Multi-arch support** (linux/amd64, linux/arm64)

See [.github/CI_CD_QUICK_START.md](.github/CI_CD_QUICK_START.md) for details.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   DNS Client                        │
└──────────────────────┬──────────────────────────────┘
                       │ Port 53
                       ▼
┌──────────────────────────────────────────────────────┐
│               AdGuard Home                           │
│  • Ad blocking & filtering                           │
│  • Web UI (port 3000)                                │
└──────────────────────┬───────────────────────────────┘
                       │ Port 5335
                       ▼
┌──────────────────────────────────────────────────────┐
│               Unbound DNS                            │
│  • DNSSEC validation                                 │
│  • Recursive resolution                              │
│  • Memory cache (384MB)                              │
└──────────────────────┬───────────────────────────────┘
                       │
                       ├──► Cloudflare DNS (1.1.1.1)
                       │    via DoT (port 853)
                       │
                       └──► Valkey Cache
                            • Unix socket (/tmp/valkey.sock)
                            • Persistent cache (8MB)
                            • Overflow/persistence
```

## Recent Improvements

### v2.0 - Security & Automation Release

**Docker Compose + Makefile**
- Simple orchestration with docker-compose.yml
- Comprehensive Makefile with color-coded output
- Easy testing and deployment commands

**Comprehensive Testing**
- Smoke tests (Unbound, Valkey, AdGuard)
- Integration tests (cache, E2E, ad blocking, DoT)
- BATS structured tests (15 tests with TAP output)
- tests/README.md documentation

**Security Enhancements**
- Automatic random password generation (16-char, bcrypt)
- Environment variable support (ADGUARD_PASSWORD)
- Pre-commit hooks (shellcheck, hadolint, detect-secrets)
- Trivy vulnerability scanning
- Gitleaks secret detection
- .secrets.baseline for false positive management

**CI/CD Optimization**
- Parallel multi-arch builds (40-84% faster)
- amd64 + arm64 build simultaneously
- Dual-layer caching (Registry + GHA)
- Smart change detection
- Optimized testing (amd64 only)

**Configuration Improvements**
- Healthcheck in Dockerfile
- Improved Valkey configuration
- Better entrypoint.sh error handling
- .gitignore for data directory

## Documentation

- [.github/VERSIONING.md](.github/VERSIONING.md) - **Versioning & release automation guide**
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes
- [NEXT_IMPROVEMENTS.md](NEXT_IMPROVEMENTS.md) - Future enhancement roadmap
- [SECURITY_IMPROVEMENTS.md](SECURITY_IMPROVEMENTS.md) - Detailed security guide
- [tests/README.md](tests/README.md) - Testing documentation
- [.github/SETUP_PRECOMMIT.md](.github/SETUP_PRECOMMIT.md) - Pre-commit setup
- [.github/CI_CD_QUICK_START.md](.github/CI_CD_QUICK_START.md) - CI/CD guide
- [.github/SECURITY_QUICK_REFERENCE.md](.github/SECURITY_QUICK_REFERENCE.md) - Security quick ref

## Troubleshooting

### Can't login to AdGuard

```bash
# Check credentials
docker logs dns-stack | grep "Password:"

# Or check file
docker exec dns-stack cat /config/AdGuardHome/.credentials
```

### Reset password

```bash
docker exec dns-stack rm /config/AdGuardHome/.credentials
docker restart dns-stack
# New password will be generated
```

### View service status

```bash
make status
make health
make logs
```

## Contributing

1. Fork the repository
2. Install pre-commit hooks: `pre-commit install`
3. Create feature branch
4. Make changes and test: `make test`
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/) format:
   - `feat: add new feature` (minor version bump)
   - `fix: resolve bug` (patch version bump)
   - `docs: update documentation` (patch version bump)
   - See [.github/VERSIONING.md](.github/VERSIONING.md) for details
6. Push and create PR

### Commit Message Format

```bash
# Feature
git commit -m "feat: add Prometheus metrics endpoint"

# Bug fix
git commit -m "fix: correct Valkey socket permissions"

# Breaking change
git commit -m "feat!: change config structure

BREAKING CHANGE: Config files moved to new location"
```

Releases are automatically created when commits are merged to `main`.

## License

[Your License]

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/repo/issues)
- 📖 **Documentation**: See docs above
- 🔒 **Security**: View Security tab for vulnerability reports
