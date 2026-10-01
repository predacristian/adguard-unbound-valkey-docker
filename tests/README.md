# DNS stack test suite

The suite runs against a live container: AdGuard Home on port 53,
unbound on 5335, valkey on the unix socket at `/tmp/valkey.sock`.

## Layout

```
tests/
├── test_architecture.sh       # AdGuard binary exists, runs, matches the CPU
├── test_unbound.sh            # process, port, resolution, reverse DNS, timing
├── test_valkey.sh             # process, socket, PING, SET/GET/DEL, timing
├── test_adguard.sh            # process, port, web UI, DNS through port 53
├── test_cache_integration.sh  # unbound-to-valkey cachedb integration
├── test_e2e_query.sh          # full query path and record types
├── test_ad_blocking.sh        # ad domains blocked, legitimate domains resolve
├── test_dot.sh                # reports the DoT state (see below)
└── integration.bats           # BATS suite covering all of the above
```

## Running

```bash
make up          # start the stack, wait for healthy
make test        # build, start, run everything, tear down (~3 min)
make test-smoke  # the four smoke scripts (~30s)
make test-bats   # just the BATS suite (~60s)
```

The individual suites need a running container:

```bash
make test-unbound
make test-valkey
make test-adguard
make test-cache
make test-e2e
make test-ad-blocking
make test-dot
```

## What the tests assert

Smoke: each service process is up, listening, and answering. Unbound
must resolve within 1 second; valkey must round-trip a write and read.

Cache integration: the unix socket exists with the right permissions,
and after a query through unbound the valkey key count grows. A query
answered from unbound's memory cache never reaches valkey, so the
BATS cache tests try several domains until one misses memory; if none
of them lands in valkey, the test fails.

Ad blocking: doubleclick.net must not resolve to a real IP. The test
retries for about 30 seconds because AdGuard downloads filter lists
asynchronously on first boot; after that a real IP is a failure.
google.com, github.com and cloudflare.com must resolve.

DNSSEC: dnssec.works must return NOERROR, and dnssec-failed.org
(deliberately mis-signed) must return SERVFAIL. Both tests retry, since
a cold cache can take longer than one dig round to validate a chain.

DoT: with the shipped config nothing listens on 853, and the suite
asserts that. If you enable TLS in the AdGuard config, update the
assertion in `integration.bats`.

Timing: queries through the full chain stay within the per-test bounds
(a couple of seconds).

## CI

The suite runs on pull requests, on `renovate/**` branches, and on
main before a release publishes. It lives in
`.github/workflows/tests.yml`; the order is smoke, integration, BATS,
then Trivy. A fixable CRITICAL Trivy finding fails the run.

## Debugging a failure

```bash
make logs
docker exec dns-stack dig +short @127.0.0.1 -p 5335 example.com
docker exec dns-stack valkey-cli -s /tmp/valkey.sock INFO memory
```

Valkey socket not found: valkey did not start. Look for its startup
error in `make logs`.

No cache entries after a query: either unbound served the answer from
its memory cache, or cachedb is broken. The BATS cache tests rule out
the first case by trying several domains.

Ad domains not blocked: the filters may still be downloading. Check
whether protection is on:

```bash
docker exec dns-stack curl -s http://127.0.0.1:3000/control/status | grep protection_enabled
```

One gotcha in any custom test: dig prints its `;; communications error`
chatter to stdout on failure, so filter those lines before checking
that a query returned an answer.

## Adding a test

Shell scripts follow the existing shape: `log`, one function per
check, failures `exit 1`, a `main` that calls them in order under
`set -e`. In BATS:

```bash
@test "description" {
    run sh -c "dig +time=5 +tries=1 @127.0.0.1 -p 5335 +short example.org 2>/dev/null | grep -v '^;;'"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
```

Then:

1. Put the script in `tests/` and make it executable.
2. Add a make target under `##@ Testing` in the Makefile.
3. Wire it into `.github/workflows/tests.yml` if it should gate CI.

## References

- [BATS documentation](https://bats-core.readthedocs.io/)
- [Unbound documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Valkey documentation](https://valkey.io/documentation/)
- [AdGuard Home API](https://github.com/AdguardTeam/AdGuardHome/wiki/API)
