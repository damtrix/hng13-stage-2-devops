# Blue/Green Node.js Deployment with Nginx

This deployment provides a Blue/Green Node.js service setup behind Nginx with automated failover capabilities.

## Architecture

- **Nginx**: Load balancer with failover logic
- **Blue Service**: Primary service (port 8081)
- **Green Service**: Backup service (port 8082)
- **Main Entry Point**: http://localhost:8080

## Features

- ✅ Automatic failover from Blue to Green on service failure
- ✅ Zero-downtime deployments
- ✅ Health-based routing
- ✅ Chaos engineering support
- ✅ Header preservation (X-App-Pool, X-Release-Id)
- ✅ Retry logic for failed requests

## Prerequisites

### Ubuntu Server Setup

If you're setting up a new Ubuntu server, run the Docker installation script first:

```bash
# Make executable and run
chmod +x server-setup.sh
./server-setup.sh
```

This script will:

- Update system packages
- Install Docker prerequisites
- Add Docker GPG key and repository
- Install Docker CE, Docker Compose, and related tools
- Configure Docker service
- Add your user to the docker group
- Verify installation with tests

## Quick Start

1. **Copy environment template:**

   ```bash
   cp env.template .env
   ```

2. **Deploy the application:**

   ```bash
   ./deploy.sh
   ```

3. **Test the deployment:**
   ```bash
   ./test-deployment.sh
   ```

## Shell Scripts

### Server Setup Scripts

#### `server-setup.sh` - Ubuntu Docker Installation

- **Purpose**: Complete Docker installation and configuration on Ubuntu servers
- **Features**:
  - System package updates and upgrades
  - Docker prerequisites installation (ca-certificates, curl, gnupg)
  - Docker GPG key addition and repository setup
  - Docker CE, Docker Compose, and plugins installation
  - User group configuration (adds user to docker group)
  - Service configuration and startup
  - Comprehensive installation verification
  - Error handling with cleanup on failure
  - Post-installation instructions and useful commands
- **Usage**: `./server-setup.sh`
- **Requirements**: Ubuntu 20.04+, sudo privileges, non-root user

### Core Deployment Scripts

#### `deploy.sh` - Automated Deployment

- **Purpose**: Complete deployment automation with health checks
- **Features**:
  - Creates `.env` from template if missing
  - Verifies Docker is running
  - Pulls required Docker images
  - Starts all services with `docker compose up -d`
  - Performs comprehensive health checks on all services
  - Displays service status and endpoints
- **Usage**: `./deploy.sh`

#### `startup.sh` - Nginx Configuration Generator

- **Purpose**: Dynamic Nginx configuration based on environment variables
- **Features**:
  - Generates Nginx config based on `ACTIVE_POOL` environment variable
  - Configures upstream failover with Blue/Green pools
  - Sets up health-based routing with timeout configurations
  - Preserves all upstream headers (`X-App-Pool`, `X-Release-Id`)
  - Configures retry logic for failed requests
- **Usage**: Automatically executed by Docker Compose

### Testing & Verification Scripts

#### `test-deployment.sh` - Comprehensive Testing Suite

- **Purpose**: End-to-end testing of Blue/Green deployment
- **Features**:
  - Baseline functionality testing
  - Direct service access verification
  - Chaos simulation testing
  - Load testing during failures
  - Health check validation
  - Failover behavior verification
- **Usage**: `./test-deployment.sh`

#### `verify-requirements.sh` - Requirements Verification

- **Purpose**: Validates all deployment requirements are met
- **Features**:
  - Tests all endpoints (main, blue, green)
  - Verifies header forwarding (`X-App-Pool`, `X-Release-Id`)
  - Tests chaos endpoints functionality
  - Validates failover behavior
  - Checks environment configuration
  - Verifies Docker Compose services
  - Provides detailed pass/fail summary
- **Usage**: `./verify-requirements.sh`

#### `demo-failover.sh` - Interactive Failover Demonstration

- **Purpose**: Real-time demonstration of failover behavior
- **Features**:
  - Shows baseline operation (Blue active)
  - Simulates chaos on Blue service
  - Demonstrates automatic failover to Green
  - Shows recovery back to Blue
  - Color-coded output for easy visualization
  - Step-by-step explanation of each phase
- **Usage**: `./demo-failover.sh`

### Utility Scripts

#### `cleanup.sh` - Complete Environment Cleanup

- **Purpose**: Clean removal of all deployment resources
- **Features**:
  - Stops and removes all containers
  - Optional volume removal with user confirmation
  - Optional image removal with user confirmation
  - Cleans up dangling Docker resources
  - Interactive prompts for destructive operations
- **Usage**: `./cleanup.sh`

## Environment Variables

| Variable           | Default                                | Description                    |
| ------------------ | -------------------------------------- | ------------------------------ |
| `BLUE_IMAGE`       | `yimikaade/wonderful:devops-stage-two` | Docker image for Blue service  |
| `GREEN_IMAGE`      | `yimikaade/wonderful:devops-stage-two` | Docker image for Green service |
| `ACTIVE_POOL`      | `blue`                                 | Active pool (blue or green)    |
| `RELEASE_ID_BLUE`  | `blue-release-v1.0.0`                  | Release ID for Blue service    |
| `RELEASE_ID_GREEN` | `green-release-v1.0.0`                 | Release ID for Green service   |
| `PORT`             | `8080`                                 | Main application port          |

## Endpoints

### Main Application (via Nginx)

- `GET http://localhost:8080/version` - Get version info
- `GET http://localhost:8080/healthz` - Health check

### Direct Service Access

- `GET http://localhost:8081/version` - Blue service direct
- `GET http://localhost:8082/version` - Green service direct

### Chaos Engineering

- `POST http://localhost:8081/chaos/start?mode=error` - Start chaos on Blue
- `POST http://localhost:8081/chaos/stop` - Stop chaos on Blue
- `POST http://localhost:8082/chaos/start?mode=error` - Start chaos on Green
- `POST http://localhost:8082/chaos/stop` - Stop chaos on Green

## Response Headers

The services return these headers:

- `X-App-Pool`: `blue` or `green` (indicates which pool served the request)
- `X-Release-Id`: Release identifier for the service

## Failover Behavior

1. **Normal Operation**: All traffic goes to the active pool (Blue by default)
2. **Failure Detection**: Nginx detects failures via:
   - HTTP 5xx status codes
   - Connection timeouts
   - Read timeouts
3. **Automatic Failover**: Traffic automatically switches to the backup pool
4. **Retry Logic**: Failed requests are retried on the backup pool within the same client request

## Testing

Multiple testing approaches are available for comprehensive validation:

### Automated Testing Scripts

```bash
# Comprehensive end-to-end testing
./test-deployment.sh

# Requirements verification
./verify-requirements.sh

# Interactive failover demonstration
./demo-failover.sh
```

### Manual Testing

```bash
# Basic functionality
curl http://localhost:8080/version
curl http://localhost:8080/healthz

# Direct service access
curl http://localhost:8081/version  # Blue service
curl http://localhost:8082/version  # Green service

# Chaos simulation
curl -X POST http://localhost:8081/chaos/start?mode=error
curl http://localhost:8080/version  # Should now come from Green
curl -X POST http://localhost:8081/chaos/stop
```

### Testing Features

1. **Baseline Testing**: Verifies normal operation
2. **Direct Access Testing**: Tests direct service access
3. **Chaos Simulation**: Tests failover behavior
4. **Load Testing**: Continuous requests during chaos
5. **Health Checks**: Verifies service health
6. **Header Validation**: Confirms proper header forwarding
7. **Recovery Testing**: Validates return to primary service

## Configuration

### Nginx Configuration

The Nginx configuration is dynamically generated based on the `ACTIVE_POOL` environment variable:

- **Blue Active**: Blue as primary, Green as backup
- **Green Active**: Green as primary, Blue as backup

### Timeout Settings

- **Connection Timeout**: 2s
- **Send Timeout**: 5s
- **Read Timeout**: 5s
- **Fail Timeout**: 5s
- **Max Fails**: 1

## Troubleshooting

### Automated Diagnostics

```bash
# Comprehensive requirements verification
./verify-requirements.sh

# Interactive failover demonstration
./demo-failover.sh

# Complete cleanup and redeploy
./cleanup.sh
./deploy.sh
```

### Manual Diagnostics

```bash
# Check service status
docker compose ps
docker compose logs nginx
docker compose logs app-blue
docker compose logs app-green

# Verify configuration
curl -I http://localhost:8080/version | grep X-App-Pool

# Test direct access
curl http://localhost:8081/version
curl http://localhost:8082/version
```

### Common Issues

1. **Services not starting**: Check Docker images are available
2. **Port conflicts**: Ensure ports 8080, 8081, 8082 are available
3. **Failover not working**: Check Nginx logs for upstream errors
4. **Headers missing**: Verify proxy_pass_header configuration

## Production Considerations

- Monitor upstream health via Nginx logs
- Set up proper logging and monitoring
- Consider using external load balancers for high availability
- Implement proper backup and recovery procedures
- Monitor failover events and response times
