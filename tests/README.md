# DNS Stack Test Suite

Comprehensive test suite for the DNS Stack (AdGuard + Unbound + Valkey) Docker container.

## Test Structure

```
tests/
├── README.md                      # This file
├── test_unbound.sh                # Smoke tests for Unbound
├── test_valkey.sh                 # Smoke tests for Valkey
├── test_adguard.sh                # Smoke tests for AdGuard
├── test_cache_integration.sh      # Cache integration tests (NEW!)
├── test_e2e_query.sh              # End-to-end query path tests (NEW!)
├── test_ad_blocking.sh            # Ad blocking functionality tests (NEW!)
├── test_dot.sh                    # DNS over TLS tests (NEW!)
└── integration.bats               # BATS integration test suite (NEW!)
```

## Test Categories

### Smoke Tests (Quick, 30s)
Basic health and functionality checks for each service.

**test_unbound.sh** - 6 tests
- Process and port checks
- Basic DNS resolution
- DNSSEC validation
- Reverse DNS
- Response time

**test_valkey.sh** - 5 tests
- Process and port checks
- Connection (PING/PONG)
- Basic operations (SET/GET/EXISTS/DEL)
- Response time

**test_adguard.sh** - 4 tests
- Process and port checks
- Web interface accessibility
- DNS resolution through AdGuard

### Integration Tests (Comprehensive, 2min)
Tests for integration between components and core functionality.

**test_cache_integration.sh** - 7 tests ⭐ CRITICAL
- Unix socket exists and accessible
- Socket permissions correct
- Unbound actually caches in Valkey (THE KEY TEST!)
- Cache hit performance
- Cache data structure
- Cache memory usage

**test_e2e_query.sh** - 7 tests
- AdGuard → Unbound forwarding
- Unbound → Cloudflare forwarding
- Full query path with caching
- Multiple DNS record types (A, AAAA, MX, TXT)
- Query timing (cache miss vs hit)

**test_ad_blocking.sh** - 7 tests
- Filtering enabled check
- Known ad domains blocked
- Legitimate domains allowed
- Filter lists loaded
- Statistics tracking
- Multiple ad domain tests
- DNSSEC not broken by blocking

**test_dot.sh** - 6 tests
- DoT port (853) listening
- TLS connection tests (multiple methods)
- Unbound DoT configuration
- Upstream DoT status

### BATS Tests (Structured, 1min)
Automated test suite using BATS framework with better output.

**integration.bats** - 17 tests
- Combines key tests from all categories
- TAP output format for CI integration
- Better assertions and error messages

## Running Tests

### Prerequisites

Container must be running:
```bash
make up
# or
docker-compose up -d
```

Wait for services to be healthy (~30-45 seconds)

### Run All Tests

```bash
# Full test suite (smoke + integration)
make test

# Quick smoke tests only
make test-smoke

# Integration tests only
make test-integration

# BATS tests only
make test-bats
```

### Run Individual Test Suites

```bash
# Smoke tests
make test-unbound
make test-valkey
make test-adguard

# Integration tests
make test-cache          # Cache integration (MOST IMPORTANT!)
make test-e2e            # End-to-end query path
make test-ad-blocking    # Ad blocking functionality
make test-dot            # DNS over TLS
```

### Run Tests Manually

```bash
# Inside container
docker exec dns-stack /tests/test_cache_integration.sh

# From host (if tests mounted)
docker exec dns-stack bash -c "cd /tests && ./test_cache_integration.sh"

# Run BATS
docker exec dns-stack bats /tests/integration.bats
```

## Test Coverage

### ✅ What IS Tested

**Core Functionality:**
- DNS resolution (A, AAAA, MX, TXT records)
- DNSSEC validation
- Reverse DNS (PTR records)
- DNS over TLS port exposure
- Ad blocking
- Query forwarding chain
- Cache integration (Unbound → Valkey)
- Cache hit/miss behavior
- Response time performance

**Service Health:**
- Process running checks
- Port availability
- Web interface accessibility
- Configuration validation

**Integration:**
- AdGuard → Unbound forwarding
- Unbound → Valkey caching via Unix socket
- Unbound → Cloudflare upstream
- Full end-to-end query path

### ❌ What IS NOT Tested

- Load testing (concurrent queries)
- Memory usage under load
- Certificate management for DoT
- IPv6 specific queries
- Custom filter rules
- AdGuard API authentication
- Service restart/recovery
- Configuration reload
- Rate limiting enforcement
- Security/penetration testing

## Test Results & Output

### Bash Scripts
Standard output with timestamps and colored status:
```
[2025-12-09 00:00:00] Running cache integration tests...
[2025-12-09 00:00:01] ✓ Socket exists at /tmp/valkey.sock
[2025-12-09 00:00:02] ✓ Unbound is caching in Valkey (5 keys added)
```

### BATS Output
TAP (Test Anything Protocol) format:
```
1..17
ok 1 Valkey Unix socket exists and is accessible
ok 2 Unbound caches DNS queries in Valkey
ok 3 Cache hits improve query performance
...
```

## CI/CD Integration

Tests are automatically run in GitHub Actions on:
- Pull requests to main
- Pushes to main
- Manual workflow dispatch

Workflow runs:
1. Smoke tests (fast verification)
2. Integration tests (comprehensive)
3. BATS tests (structured validation)

## Troubleshooting

### Test Failures

**"Valkey Unix socket not found"**
- Check entrypoint.sh started Valkey correctly
- Verify socket permissions (should be 770)
- Check Valkey config has `unixsocket /tmp/valkey.sock`

**"No cache entries after DNS query"**
- Most critical failure - means caching is broken!
- Check unbound.conf has `cachedb:` module
- Verify Unbound can write to Valkey socket
- Check Valkey is running and accessible

**"Ad domains not blocked"**
- Check AdGuard protection is enabled
- Verify filter lists are loaded
- May be expected if filters don't include that domain

**"DoT tests skipped"**
- Expected - DoT requires TLS certificate configuration
- Port 853 is exposed but TLS not configured by default

### Debug Mode

Run tests with debug output:
```bash
# Enable debug logging in scripts
DEBUG=1 docker exec dns-stack /tests/test_cache_integration.sh

# Check Valkey directly
docker exec dns-stack valkey-cli -s /tmp/valkey.sock INFO

# Check Unbound stats
docker exec dns-stack unbound-control stats_noreset

# Check container logs
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

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

test_something() {
    log "Testing something..."
    # Your test logic here
    log "✓ Test passed"
}

main() {
    log "=== Running My Tests ==="
    test_something
    log "=== ✓ All tests passed ==="
}

main "$@"
```

### BATS Test Template

```bash
@test "description of what is tested" {
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected pattern" ]]
}
```

### Adding to CI/CD

1. Add script to `tests/` directory
2. Make executable: `chmod +x tests/test_new.sh`
3. Add to Makefile under `##@ Testing`
4. Update `.github/workflows/ci-cd.yml` if needed

## Performance Benchmarks

Expected test execution times (on healthy system):

- Smoke tests: ~30 seconds
- Integration tests: ~90 seconds
- BATS tests: ~60 seconds
- Full suite: ~3 minutes

## Future Improvements

Potential enhancements for future versions:

- [ ] Performance/load testing with k6 or dnsperf
- [ ] Security scanning integration
- [ ] Metrics validation tests
- [ ] Chaos/failure testing
- [ ] Configuration validation tests
- [ ] Test result artifacts (JUnit XML)
- [ ] Test coverage tracking
- [ ] Parallel test execution
- [ ] Container structure tests

## References

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Valkey Documentation](https://valkey.io/documentation/)
- [AdGuard Home API](https://github.com/AdguardTeam/AdGuardHome/wiki/API)
