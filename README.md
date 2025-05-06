# DNS Stack

A containerized DNS solution combining Unbound DNS, AdGuard Home, and Valkey for efficient DNS resolution and ad blocking.

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

## Default Access

AdGuard Home web interface:
- URL: `http://localhost:3000`
- Default credentials:
  - Username: `admin`
  - Password: `admin`

**Important** ⚠️: Change the default password after first login for security or bring your own config.

## Configuration ⚙️

The container uses three main configuration directories:

- `/config/unbound/`: Unbound DNS configuration
- `/config/AdGuardHome/`: AdGuard Home configuration
- `/config/valkey/`: Valkey cache configuration

Default configurations are provided and copied to these locations on first run.

## Environment Variables

The container uses the following build arguments:
- `UNBOUND_VERSION`: Version of Unbound DNS to install
- `ADGUARD_VERSION`: Version of AdGuard Home to install

## Building the Docker Image 🛠️

To build the Docker image locally, use the following command:

```bash
docker build -t dns-stack .
```

## Docker Usage 🐳

```bash
docker run -d \
  --name dns-stack \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 853:853/tcp \
  -p 3000:3000/tcp \
  -v /path/to/config:/config \
  dns-stack
```
