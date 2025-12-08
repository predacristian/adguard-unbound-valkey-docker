# Pre-commit Hooks Setup Guide

Pre-commit hooks automatically check your code before each commit, catching issues early.

## Quick Setup

```bash
# Install pre-commit (one time)
pip install pre-commit

# Install hooks into your git repo (one time per clone)
cd /path/to/adguard-unbound-valkey-docker
pre-commit install

# That's it! Hooks will run automatically on git commit
```

## What Gets Checked

On every commit, these checks run automatically:

1. **ShellCheck** - Lints all shell scripts
2. **Hadolint** - Lints Dockerfile
3. **detect-secrets** - Scans for accidentally committed secrets
4. **YAML validation** - Validates YAML syntax
5. **Basic checks** - Trailing whitespace, merge conflicts, etc.
6. **Markdown linting** - Fixes markdown formatting
7. **Docker Compose validation** - Validates docker-compose.yml

## Manual Usage

```bash
# Run on all files (useful first time)
pre-commit run --all-files

# Run on staged files only
pre-commit run

# Skip hooks for emergency commits (use sparingly!)
git commit --no-verify -m "Emergency fix"
```

## Updating Hooks

```bash
# Update to latest hook versions
pre-commit autoupdate

# Clean and reinstall
pre-commit clean
pre-commit install
```

## What If a Check Fails?

### ShellCheck Failures

```bash
# Example error:
# tests/test.sh:10:5: warning: Use $(..) instead of legacy `..` [SC2006]

# Fix: Replace backticks with $(..)
result=`command`     # Bad
result=$(command)    # Good
```

### Hadolint Failures

```bash
# Example error:
# Dockerfile:10 DL3025: Use arguments JSON notation

# Fix: Use JSON array format for ENTRYPOINT/CMD
ENTRYPOINT /usr/local/bin/script.sh    # Bad
ENTRYPOINT ["/usr/local/bin/script.sh"] # Good
```

### Secret Detection

```bash
# If you get a false positive:

# 1. Update .secrets.baseline
detect-secrets scan --baseline .secrets.baseline

# 2. Or add inline comment to ignore
password = "not-a-real-password"  # pragma: allowlist secret
```

### YAML Validation

```bash
# Use yamllint or check syntax manually
yamllint docker-compose.yml
```

## CI Integration

Pre-commit hooks are also run in CI via:
```yaml
# .github/workflows/ci-cd.yml
- uses: pre-commit/action@v3.0.0
```

This ensures all commits pass checks even if someone doesn't have hooks installed locally.

## Troubleshooting

### Hooks don't run

```bash
# Verify hooks are installed
ls -la .git/hooks/pre-commit

# Reinstall if needed
pre-commit install
```

### Hooks run but fail immediately

```bash
# Update pre-commit
pip install --upgrade pre-commit

# Clean cache
pre-commit clean
```

### Skip specific hooks

```bash
# Skip shellcheck only
SKIP=shellcheck git commit -m "message"

# Skip multiple hooks
SKIP=shellcheck,hadolint git commit -m "message"
```

## Best Practices

1. **Run `pre-commit run --all-files` after setup** - Fixes existing issues
2. **Don't use `--no-verify` unless emergency** - Defeats the purpose
3. **Update hooks periodically** - `pre-commit autoupdate`
4. **Add new scripts to checks** - Pre-commit auto-detects by extension
5. **Fix issues, don't skip checks** - The checks are there to help!

## Requirements

- Python 3.7+
- pip
- git

That's it! No need to install shellcheck, hadolint, etc. separately - pre-commit handles it all.
