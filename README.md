# DNS Stack: Unbound + AdGuard Home + Valkey

![CI/CD Status](https://img.shields.io/badge/CI%2FCD-Optimized-brightgreen)
![Security Scanning](https://img.shields.io/badge/Security-Trivy%20%2B%20Gitleaks-blue)
![Pre-commit Hooks](https://img.shields.io/badge/Pre--commit-Enabled-orange)
![Semantic Release](https://img.shields.io/badge/semantic--release-automated-e10079)
![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)

DNS resolver with ad blocking and persistent caching in a single Docker container.

## What This Does

- Blocks ads and trackers at DNS level
- Validates DNSSEC signatures
- Caches DNS queries using Valkey for faster lookups
- Encrypts upstream DNS queries (DNS over TLS)
- Web interface for management

## Architecture

```
DNS Client (your device)
        │
        ▼
AdGuard Home (port 53)
  • Blocks ads/trackers
  • Web UI (port 3000)
        │
        ▼
Unbound DNS (port 5335)
  • DNSSEC validation
  • Recursive resolution
  • 384MB memory cache
        │
        ├──► Cloudflare DNS (1.1.1.1) via DoT
        └──► Valkey Cache (Unix socket)
             • Persistent storage
             • 8MB cache
```

## Quick Start

### Requirements

- Docker 20.10+
- Docker Compose 2.0+
- 512MB RAM minimum

### Start the Stack

```bash
# Clone repo
git clone https://github.com/yourusername/adguard-unbound-valkey-docker.git
cd adguard-unbound-valkey-docker

# Start services
make up

# Get password (auto-generated)
make logs | grep "Password:"

# Access web UI
open http://localhost:3000
```

Default login: `admin` / (password from logs)

### Configure Devices

Point your devices DNS to your host machine's IP address on port 53.

## Ports

| Port | Service |
|------|---------|
| 53 | DNS (TCP/UDP) |
| 853 | DNS-over-TLS |
| 3000 | AdGuard Web UI |
| 8443 | HTTPS (when enabled) |

## Configuration

### Directory Structure

```
data/config/
├── AdGuardHome/
│   ├── AdGuardHome.yaml
│   └── .credentials
├── unbound/
│   ├── unbound.conf
│   └── unbound.conf.d/
└── valkey/
    └── valkey.conf
```

### Environment Variables

Edit `docker-compose.yml`:

```yaml
environment:
  TZ: "America/New_York"
  ADGUARD_PASSWORD: "YourPassword"
  ADGUARD_USERNAME: "admin"
```

### Password Management

**Auto-generated:**
- Random password if `ADGUARD_PASSWORD` not set
- Shown in logs on first run
- Saved to `.credentials` file

**Reset password:**
```bash
make down
rm ./data/config/AdGuardHome/.credentials
make up
```

## Usage

### Makefile Commands

```bash
make up           # Start stack
make down         # Stop stack
make restart      # Restart services
make logs         # View logs
make status       # Container status
make health       # Health check
make shell        # Open shell
```

### Testing DNS

```bash
# Test DNS resolution
dig @localhost example.com

# Test AAAA record
dig @localhost AAAA example.com

# Check if ads are blocked
dig @localhost ads.example.com
```

### Monitoring Services

```bash
# Check health
make health

# Watch logs
make logs

# Inside container
make shell
unbound-control status
valkey-cli -s /tmp/valkey.sock PING
```

## Testing

Full test suite included:

```bash
make test              # All tests (~3 min)
make test-smoke        # Quick health checks (~30s)
make test-integration  # Component integration (~90s)
make test-cache        # Cache functionality
make test-e2e          # End-to-end queries
```

See [tests/README.md](tests/README.md) for details.

## Building

```bash
# Build image
make build

# Build without cache
make rebuild

# Custom versions
docker build \
  --build-arg UNBOUND_VERSION=1.23.1 \
  --build-arg ADGUARD_VERSION=v0.107.71 \
  -t dns-stack:custom .
```

## Development

### Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
```

Includes: shellcheck, hadolint, secret detection, YAML validation

### Commit Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
git commit -m "feat: add new feature"
git commit -m "fix: correct bug"
git commit -m "docs: update readme"
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

### Making Changes

1. Create branch: `git checkout -b feature/name`
2. Make changes
3. Test: `make rebuild && make test`
4. Commit and push
5. Create PR

## CI/CD

GitHub Actions workflows:
- **ci-cd.yml**: Build multi-arch images, run tests, push to GHCR
- **security.yml**: Trivy + Gitleaks scanning
- **release.yml**: Semantic versioning and releases

Releases created automatically on merge to `main`.

## Security

### Scanning

- **Trivy**: Container vulnerability scanning
- **Gitleaks**: Secret detection in git history

Results: Repository → Security tab

### Recommendations

- Set custom password in `docker-compose.yml`
- Use specific version tags (not `:latest`)
- Keep images updated
- Restrict web UI to localhost if needed:
  ```yaml
  ports:
    - "127.0.0.1:3000:3000"
  ```

## Troubleshooting

### Can't Login

```bash
# Get password
docker logs dns-stack | grep "Password:"

# Reset
make down
rm ./data/config/AdGuardHome/.credentials
make up
```

### DNS Not Working

```bash
# Check health
make health

# Test resolution
dig @localhost example.com

# Check logs
make logs
```

### Cache Issues

```bash
make shell
valkey-cli -s /tmp/valkey.sock PING
valkey-cli -s /tmp/valkey.sock KEYS "*"
```

### Port 53 Conflict

```bash
# Check what's using port
sudo lsof -i :53

# Stop systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### Container Crashes

```bash
# View logs
docker logs dns-stack
```

Common causes:
- Insufficient memory (need 512MB+)
- Port conflicts
- Missing capabilities (NET_ADMIN, NET_BIND_SERVICE)

## License

MIT License

## Acknowledgments

- [Unbound DNS](https://nlnetlabs.nl/projects/unbound/)
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)
- [Valkey](https://github.com/valkey-io/valkey)
- [Alpine Linux](https://alpinelinux.org/)
