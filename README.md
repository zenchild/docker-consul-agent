# DockerConsulAgent

A lightweight Elixir application that automatically registers Docker containers with Consul based on container labels.

## Overview

DockerConsulAgent listens to the Docker socket for container events and registers appropriately labeled containers as services in Consul. This enables automatic service discovery for your containerized applications.

## Configuration

### Docker

The agent connects to the Docker daemon through its socket:

| Environment Variable | Default                | Description               |
| -------------------- | ---------------------- | ------------------------- |
| `DOCKER_SOCKET`      | `/var/run/docker.sock` | Path to the Docker socket |

### Consul

Configure your Consul connection with these environment variables:

| Environment Variable     | Required | Description                                   |
| ------------------------ | -------- | --------------------------------------------- |
| `CONSUL_HTTP_ADDR`       | Yes      | Consul agent address (e.g., `localhost:8500`) |
| `CONSUL_HTTP_TOKEN`      | Yes      | Authentication token                          |
| `CONSUL_HTTP_SSL`        | No       | Use HTTPS instead of HTTP                     |
| `CONSUL_HTTP_SSL_VERIFY` | No       | Verify SSL certificates                       |

## Usage in Docker

Add the following Docker labels to your containers:

| Label                                         | Required | Description                                    |
| --------------------------------------------- | -------- | ---------------------------------------------- |
| `consul.enabled=true`                         | Yes      | Enables Consul registration for this container |
| `consul.node_name=<string>`                   | No       | Custom node name (defaults to Docker hostname) |
| `consul.service.<service-name>.port=<port>`   | Yes      | Port mapping for the service                   |
| `consul.service.<service-name>.tags=<string>` | No       | Comma-separated list of tags                   |
| `consul.service_basename=<string>`            | No       | Prefix for service names                       |

### Example Docker Compose

```yaml
version: '3'
services:
  web:
    image: traefik
    labels:
      - "consul.enabled=true"
      - "consul.service.web.port=443"
      - "consul.service.web.tags=proxy,web"
