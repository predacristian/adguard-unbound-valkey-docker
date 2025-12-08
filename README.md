# DNS Stack

![CI/CD](https://github.com/yourusername/repo/workflows/DNS%20Stack%20CI/CD/badge.svg)
![Security Scan](https://github.com/yourusername/repo/workflows/Security%20Scan/badge.svg)
![License](https://img.shields.io/github/license/yourusername/repo)

A secure, containerized DNS solution combining Unbound DNS, AdGuard Home, and Valkey for efficient DNS resolution, caching, and ad blocking.

## Components

- **Unbound DNS**: A validating, recursive, and caching DNS resolver
- **AdGuard Home**: Network-wide ads & tracking blocking DNS server
- **Valkey**: Lightweight in-memory cache for Unbound DNS (Alpine package version)

## Features

- DNS over TLS (DoT) support
- DNS caching with Valkey backend
- Ad blocking and custom filtering through AdGuard Home
- Configurable upstream DNS providers
- Container-optimized configuration

## Default Ports

- 53 (TCP/UDP): DNS
- 853 (TCP): DNS-over-TLS
- 3000 (TCP): AdGuard Home web interface
- 443 (TCP): HTTPS for web interface (when TLS is enabled)

## 🔐 Security & Access

### AdGuard Home Web Interface

**Access:** `http://localhost:3000`

**Credentials:**
- On first run, a **random password is automatically generated** and displayed in the container logs
- Check logs: `docker logs dns-stack` or `make logs`
- Credentials are saved to `/config/AdGuardHome/.credentials`

**Custom Password (Recommended):**
```bash
# Set via environment variable
docker run -e ADGUARD_PASSWORD=YourSecurePassword123 ...

# Or with docker-compose
environment:
  ADGUARD_PASSWORD: YourSecurePassword123
  ADGUARD_USERNAME: admin  # optional, defaults to 'admin'
```

⚠️ **Security Note:** If `ADGUARD_PASSWORD` is not set, a random password will be generated. The default `admin/admin` is only used as a fallback if password hashing fails.

## Configuration ⚙️

The container uses three main configuration directories:

- `/config/unbound/`: Unbound DNS configuration
- `/config/AdGuardHome/`: AdGuard Home configuration
- `/config/valkey/`: Valkey cache configuration

Default configurations are provided and copied to these locations on first run.

## Environment Variables

### Runtime Configuration
- `ADGUARD_PASSWORD`: Custom password for AdGuard Home (recommended)
- `ADGUARD_USERNAME`: Custom username (default: `admin`)
- `TZ`: Timezone (default: `UTC`)

### Build Arguments
- `ALPINE_VERSION`: Alpine Linux version (default: `3.23.0`)
- `UNBOUND_VERSION`: Unbound DNS version (default: `1.23.1`)
- `ADGUARD_VERSION`: AdGuard Home version (default: `v0.107.71`)
- `VALKEY_VERSION`: Valkey version (default: `9.0.0`)

## Building the Docker Image 🛠️

To build the Docker image locally, use the following command:

```bash
docker build -t dns-stack .
```

## Quick Start 🚀

### Using Docker Compose (Recommended)

```bash
# Start the stack
make up

# View logs (credentials will be displayed here)
make logs

# Run tests
make test

# Stop the stack
make down
```

### Using Docker

```bash
docker run -d \
  --name dns-stack \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 853:853/tcp \
  -p 3000:3000/tcp \
  -e ADGUARD_PASSWORD=YourSecurePassword \
  -v ./config:/config \
  dns-stack
```

## Testing

The project includes comprehensive test suites:

```bash
make test              # Full test suite
make test-smoke        # Quick smoke tests
make test-integration  # Integration tests only
make test-bats         # BATS structured tests
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

## Development

### Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

Hooks automatically check:
- Shell script linting (shellcheck)
- Dockerfile linting (hadolint)
- Secret detection
- YAML validation
- Markdown formatting

See [.github/SETUP_PRECOMMIT.md](.github/SETUP_PRECOMMIT.md) for details.

### Security Scanning

The project automatically scans for vulnerabilities using:
- **Trivy**: Container vulnerability scanning
- **Gitleaks**: Secret scanning in git history
- Runs on every push and daily via GitHub Actions

View security reports in the **Security** tab of the GitHub repository.
