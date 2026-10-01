# DNS Stack: Unbound + AdGuard Home + Valkey

![CI/CD Status](https://img.shields.io/badge/CI%2FCD-Optimized-brightgreen)
![Security Scanning](https://img.shields.io/badge/Security-Trivy%20%2B%20Gitleaks-blue)
![Pre-commit Hooks](https://img.shields.io/badge/Pre--commit-Enabled-orange)
![Semantic Release](https://img.shields.io/badge/semantic--release-automated-e10079)
![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)

DNS resolver with ad blocking and caching in a single Docker container.

## What this does

- Blocks ads and trackers at the DNS level
- Validates DNSSEC signatures and rejects domains with broken ones
- Caches queries in unbound's memory cache and in Valkey (the RDB snapshot survives container restarts)
- Forwards upstream queries over DNS-over-TLS
- Provides a web interface for management

## Architecture

```
DNS client (your device)
        |
        v
AdGuard Home (port 53)
  - blocks ads and trackers
  - web UI (port 3000)
        |
        v
Unbound (port 5335)
  - DNSSEC validation
  - 384MB memory cache
        |
        +--> Quad9 / Cloudflare / Mullvad over DoT (port 853)
        +--> Valkey (unix socket /tmp/valkey.sock)
               - second-level cache, 64MB, allkeys-lru
```

Unbound does not recurse on its own. Every query is validated, then
forwarded to one of the DoT upstreams listed in
`config/unbound/unbound.conf.d/forward-queries.conf`.

## Quick start

Requirements: Docker 20.10+, Docker Compose 2.0+, 512MB RAM.

```bash
git clone https://github.com/predacristian/adguard-unbound-valkey-docker.git
cd adguard-unbound-valkey-docker
make up

# First run only: the admin password is generated and printed once
make logs | grep "Password:"
```

The web UI is at http://localhost:3000. The username is `admin`; the
password is random unless you set `ADGUARD_PASSWORD`.

Point your devices' DNS at the host machine's IP, port 53.

## Ports

| Port | Service | Notes |
|------|---------|-------|
| 53 | DNS (TCP/UDP) | AdGuard Home, always on |
| 3000 | AdGuard web UI | always on |
| 853 | DNS-over-TLS | only when `tls.enabled: true` in AdGuardHome.yaml |
| 443 | DNS-over-HTTPS / HTTPS | only when `tls.enabled: true` in AdGuardHome.yaml |

With the shipped config (`tls.enabled: false`) nothing listens on 853
or 443. Upstream queries are always encrypted.

Unbound itself refuses recursion from anything but localhost, so even
on a published port you expose AdGuard, not an open resolver.

## Configuration

The container keeps its configuration in `data/config/`, bind-mounted
at `/config`. On first start the defaults from `config/` are copied
there. After that, edit the copies in `data/config/`.

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

### Environment variables

Only these affect the running container:

- `TZ`: timezone
- `ADGUARD_USERNAME`: web UI username (default `admin`)
- `ADGUARD_PASSWORD`: web UI password. If unset, a random one is
  generated and printed in the logs on first run.

The other variables in `.env.template` are not wired to anything yet.
To tune unbound or valkey, edit the files under `config/`.

### Resetting the admin password

```bash
make down
rm ./data/config/AdGuardHome/.credentials
make up
```

The next start generates a new password and prints it in the logs.

## Reliability

- The image has a Docker healthcheck: a DNS query through unbound, a
  valkey ping, and an HTTP check of the AdGuard UI. `make health`
  shows its status.
- The entrypoint runs the same probes roughly every 30 seconds. If a
  service dies or hangs, the container exits with an error and the
  restart policy (`restart: unless-stopped`) starts the whole stack
  again.
- Restarting the container keeps the valkey snapshot; recreating it
  (new image, changed compose file) starts with a cold cache.

## Usage

```bash
make up           # start the stack
make down         # stop it
make restart      # restart services
make logs         # follow logs
make status       # container status
make health       # healthcheck status
make shell        # shell inside the container
```

### Testing DNS

```bash
dig @localhost example.com          # resolution
dig @localhost AAAA example.com     # IPv6
dig @localhost doubleclick.net      # blocked: no answer or 0.0.0.0
```

### Inside the container

```bash
dig +short @127.0.0.1 -p 5335 example.com   # query unbound directly
valkey-cli -s /tmp/valkey.sock PING         # cache reachable
valkey-cli -s /tmp/valkey.sock DBSIZE       # cached entries
```

## Testing

```bash
make test              # build, start, run everything, tear down (~3 min)
make test-smoke        # smoke checks (~30s)
make test-integration  # component integration (~90s)
make test-cache        # cachedb integration
make test-e2e          # end-to-end queries
make test-bats         # BATS suite
```

Details, per-script coverage, and debugging tips are in
[tests/README.md](tests/README.md).

## Building

```bash
make build     # with cache
make rebuild   # without cache

# Override component versions
docker build \
  --build-arg UNBOUND_VERSION=1.23.1 \
  --build-arg ADGUARD_VERSION=v0.107.79 \
  -t dns-stack:custom .
```

## Development

Install the hooks once:

```bash
pip install pre-commit
pre-commit install
```

They run shellcheck, hadolint, secret detection, and YAML validation.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`); semantic-release
derives the version from them.

To make a change:

1. Branch off main: `git checkout -b feature/name`
2. Make the change
3. Verify: `make rebuild && make test`
4. Commit and push, open a PR
5. CI builds and runs the suite against the PR

## CI and releases

- Pull requests run the full suite from `.github/workflows/tests.yml`:
  image build, health wait, smoke, integration, and BATS tests.
- Pushes to main run the same suite, and a release publishes only if
  it passes. semantic-release then cuts the version and the amd64 and
  arm64 images are pushed to GHCR.
- Renovate updates dependencies and automerges only once that suite
  is green.
- `security.yml` runs Trivy and Gitleaks daily.

## Security

- Trivy scans the built image on every PR and daily on main. A fixable
  CRITICAL finding fails the build. Findings appear under the
  repository's Security tab.
- Gitleaks scans the entire git history daily.

Recommendations:

- Set `ADGUARD_PASSWORD` instead of relying on the generated one
- Pin an exact version tag rather than `:latest`
- If the web UI should not be reachable from the network, bind it to
  localhost:
  ```yaml
  ports:
    - "127.0.0.1:3000:3000"
  ```

## Troubleshooting

### Cannot log in

```bash
docker logs dns-stack | grep "Password:"
```

To force a new password, see [Resetting the admin password](#resetting-the-admin-password).

### DNS not working

```bash
make health
dig @localhost example.com
make logs
```

### Cache problems

```bash
make shell
valkey-cli -s /tmp/valkey.sock PING
valkey-cli -s /tmp/valkey.sock DBSIZE
```

### Port 53 already in use

```bash
sudo lsof -i :53

# on systemd distros, stop and disable the local stub resolver
sudo systemctl disable --now systemd-resolved
```

### Container keeps restarting

```bash
docker logs dns-stack
```

Usual causes: not enough memory (512MB minimum), a port conflict, or
missing NET_ADMIN / NET_BIND_SERVICE capabilities.

## License

MIT

## Acknowledgments

- [Unbound DNS](https://nlnetlabs.nl/projects/unbound/)
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)
- [Valkey](https://github.com/valkey-io/valkey)
- [Alpine Linux](https://alpinelinux.org/)
