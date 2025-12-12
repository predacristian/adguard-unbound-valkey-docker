# DNS Stack Test Suite

Tests for the DNS Stack (AdGuard + Unbound + Valkey).

## Test Structure

```
tests/
├── test_unbound.sh              # Unbound smoke tests
├── test_valkey.sh               # Valkey smoke tests
├── test_adguard.sh              # AdGuard smoke tests
├── test_cache_integration.sh    # Cache functionality
├── test_e2e_query.sh            # End-to-end query path
├── test_ad_blocking.sh          # Ad blocking tests
├── test_dot.sh                  # DNS over TLS tests
└── integration.bats             # BATS test suite
```

## Running Tests

### Prerequisites

Container must be running:
```bash
make up
# Wait 30-45 seconds for services to be healthy
make status
```

### Quick Start

```bash
# All tests
make test

# Smoke tests only (fast)
make test-smoke

# Integration tests only
make test-integration

# BATS tests
make test-bats
```

### Individual Tests

```bash
make test-unbound        # DNS resolution, DNSSEC
make test-valkey         # Cache connectivity
make test-adguard        # Web UI, DNS queries
make test-cache          # Cache integration (important)
make test-e2e            # Full query chain
make test-ad-blocking    # Ad blocking functionality
```

## What Each Test Does

### Smoke Tests (30 seconds)

Basic health checks for each service.

**test_unbound.sh** - 6 tests
- Process running
- Port listening
- DNS resolution works
- DNSSEC validation
- Reverse DNS
- Response time check

**test_valkey.sh** - 5 tests
- Process running
- Unix socket exists
- PING/PONG works
- SET/GET/EXISTS/DEL operations
- Response time check

**test_adguard.sh** - 4 tests
- Process running
- Port listening
- Web UI accessible
- DNS resolution through AdGuard

### Integration Tests (2 minutes)

Tests for component interactions.

**test_cache_integration.sh** - 7 tests
- Unix socket exists
- Socket permissions correct
- Unbound caches in Valkey
- Cache hit improves performance
- Cache data structure valid
- Cache memory usage

**test_e2e_query.sh** - 7 tests
- AdGuard → Unbound forwarding
- Unbound → Cloudflare forwarding
- Full query path with caching
- Multiple record types (A, AAAA, MX, TXT)
- Query timing (cache miss vs hit)

**test_ad_blocking.sh** - 7 tests
- Filtering enabled
- Known ad domains blocked
- Legitimate domains allowed
- Filter lists loaded
- Statistics tracking
- DNSSEC works with blocking

**test_dot.sh** - 6 tests
- DoT port (853) listening
- TLS connection tests
- Unbound DoT configuration
- Upstream DoT status

### BATS Tests (1 minute)

Structured test suite with TAP output format.

**integration.bats** - 17 tests
- Combines key tests from all categories
- Better output format
- Better assertions

## Test Results

**Bash scripts output:**
```
[2025-12-09 00:00:00] Running tests...
[2025-12-09 00:00:01] ✓ Socket exists
[2025-12-09 00:00:02] ✓ Cache working
```

**BATS output (TAP format):**
```
1..17
ok 1 Valkey socket accessible
ok 2 Unbound caches in Valkey
ok 3 Cache improves performance
```

## What Gets Tested

**Working:**
- DNS resolution (all record types)
- DNSSEC validation
- Reverse DNS
- Query forwarding chain
- Unbound → Valkey caching
- Ad blocking
- Cache hit/miss behavior
- Response times

**Not tested:**
- Load testing
- IPv6 queries
- Certificate management
- Service recovery
- Rate limiting

## Troubleshooting

### "Valkey socket not found"

Check entrypoint started Valkey:
```bash
make logs
docker exec dns-stack ls -la /tmp/valkey.sock
```

### "No cache entries after query"

This means caching is broken:
```bash
# Check Valkey running
docker exec dns-stack valkey-cli -s /tmp/valkey.sock PING

# Check Unbound config
docker exec dns-stack grep -r cachedb /config/unbound/
```

### "Ad domains not blocked"

Check AdGuard protection enabled:
```bash
docker exec dns-stack curl -s http://localhost:3000/control/status | grep protection_enabled
```

### "DoT tests skipped"

Expected - DoT requires TLS certificate configuration. Port 853 is exposed but TLS not configured by default.

## Debug Mode

```bash
# Enable debug in scripts
DEBUG=1 docker exec dns-stack /tests/test_cache_integration.sh

# Check Valkey
docker exec dns-stack valkey-cli -s /tmp/valkey.sock INFO

# Check Unbound stats
docker exec dns-stack unbound-control stats_noreset

# View logs
docker logs dns-stack
```

## Adding New Tests

### Bash Script Template

```bash
#!/bin/sh
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

test_something() {
    log "Testing something..."
    # Test logic here
    log "✓ Test passed"
}

main() {
    log "=== Running Tests ==="
    test_something
    log "=== ✓ All tests passed ==="
}

main "$@"
```

### BATS Template

```bash
@test "description" {
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected pattern" ]]
}
```

### Add to Project

1. Create script in `tests/` directory
2. Make executable: `chmod +x tests/test_new.sh`
3. Add target to `Makefile` under `##@ Testing`
4. Update `.github/workflows/ci-cd.yml` if needed

## Performance

Expected test times on healthy system:

- Smoke tests: ~30 seconds
- Integration tests: ~90 seconds
- BATS tests: ~60 seconds
- Full suite: ~3 minutes

## CI/CD Integration

Tests run automatically in GitHub Actions:
- Pull requests to main
- Pushes to main
- Manual workflow dispatch

Workflow order:
1. Smoke tests (fast verification)
2. Integration tests (comprehensive)
3. BATS tests (structured validation)

## References

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Valkey Documentation](https://valkey.io/documentation/)
- [AdGuard Home API](https://github.com/AdguardTeam/AdGuardHome/wiki/API)
