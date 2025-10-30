# Architectural Decision Records (ADR)

This document explains the design decisions and rationale behind the Blue/Green Node.js deployment architecture.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Design Decisions](#core-design-decisions)
3. [Script Design Rationale](#script-design-rationale)
4. [Configuration Management](#configuration-management)
5. [Testing Strategy](#testing-strategy)
6. [Operational Considerations](#operational-considerations)

## Architecture Overview

### Why Blue/Green Deployment?

**Decision**: Implement Blue/Green deployment pattern for zero-downtime deployments and instant failover capabilities.

**Rationale**:

- **Zero Downtime**: Eliminates deployment windows and service interruptions
- **Instant Rollback**: Can immediately switch back to previous version if issues arise
- **Risk Mitigation**: New version runs alongside old version for validation
- **Production Readiness**: Industry standard for mission-critical applications

### Why Nginx as Load Balancer?

**Decision**: Use Nginx as the load balancer and reverse proxy.

**Rationale**:

- **Mature Technology**: Battle-tested in production environments
- **Built-in Failover**: Native upstream failover capabilities
- **Performance**: High-performance, low-latency proxy
- **Flexibility**: Extensive configuration options for custom routing
- **Health Checks**: Built-in health monitoring and automatic failover
- **Header Preservation**: Can forward custom headers from upstream services

## Core Design Decisions

### 1. Dynamic Configuration Generation

**Decision**: Generate Nginx configuration dynamically at runtime using `startup.sh`.

**Rationale**:

- **Environment Flexibility**: Can switch active pool without rebuilding containers
- **Configuration Consistency**: Ensures configuration matches environment variables
- **Deployment Simplicity**: Single container image works for both Blue and Green
- **Operational Control**: Can change active pool via environment variables

**Implementation**:

```bash
# startup.sh generates config based on ACTIVE_POOL
upstream active_upstream {
    server app-blue:3000 max_fails=1 fail_timeout=5s;
    server app-green:3000 backup;
}
```

### 2. Header-Based Service Identification

**Decision**: Use custom headers (`X-App-Pool`, `X-Release-Id`) to identify which service handled requests.

**Rationale**:

- **Debugging**: Easy identification of which service processed requests
- **Monitoring**: Can track traffic distribution and service health
- **Transparency**: Clear visibility into failover behavior
- **Compliance**: Meets requirements for service identification

**Implementation**:

- Services set `X-App-Pool` and `X-Release-Id` headers
- Nginx preserves these headers via `proxy_pass_header`
- Testing scripts validate header presence and values

### 3. Chaos Engineering Integration

**Decision**: Build-in chaos engineering capabilities for testing failover behavior.

**Rationale**:

- **Reliability Testing**: Proves failover works under controlled conditions
- **Confidence Building**: Demonstrates system resilience
- **Production Readiness**: Validates behavior before real failures occur
- **Documentation**: Provides concrete examples of failover behavior

**Implementation**:

- Services expose `/chaos/start` and `/chaos/stop` endpoints
- Chaos mode simulates various failure scenarios
- Testing scripts use chaos endpoints to trigger failover

## Script Design Rationale

### 1. Modular Script Architecture

**Decision**: Create separate, focused scripts for different operational needs.

**Rationale**:

- **Single Responsibility**: Each script has one clear purpose
- **Reusability**: Scripts can be used independently
- **Maintainability**: Easier to update and debug individual components
- **User Experience**: Clear, intuitive commands for different tasks

**Script Breakdown**:

- `deploy.sh`: Complete deployment automation
- `test-deployment.sh`: Comprehensive testing suite
- `verify-requirements.sh`: Requirements validation
- `demo-failover.sh`: Interactive demonstration
- `cleanup.sh`: Environment cleanup
- `startup.sh`: Configuration generation

### 2. Comprehensive Error Handling

**Decision**: Implement robust error handling and validation in all scripts.

**Rationale**:

- **Reliability**: Scripts fail fast with clear error messages
- **User Experience**: Helpful error messages guide users to solutions
- **Debugging**: Clear indication of what went wrong and where
- **Production Safety**: Prevents partial deployments or inconsistent states

**Implementation**:

```bash
set -e  # Exit on any error
# Validation checks before operations
# Clear error messages with context
# Graceful cleanup on failure
```

### 3. Color-Coded Output

**Decision**: Use color-coded terminal output for better user experience.

**Rationale**:

- **Visual Clarity**: Easy to distinguish between different types of output
- **Status Indication**: Immediate visual feedback on success/failure
- **Professional Appearance**: Polished, production-ready tooling
- **Accessibility**: Clear visual hierarchy of information

**Color Scheme**:

- 🔵 Blue: Information and status
- 🟢 Green: Success and healthy states
- 🟡 Yellow: Warnings and in-progress operations
- 🔴 Red: Errors and failures

## Configuration Management

### 1. Environment-Based Configuration

**Decision**: Use environment variables for all configuration with sensible defaults.

**Rationale**:

- **Flexibility**: Easy to change configuration without code changes
- **Security**: Sensitive data can be injected at runtime
- **Deployment**: Same code works across different environments
- **Documentation**: Clear configuration options in `.env` template

**Configuration Areas**:

- Docker image versions
- Active pool selection
- Release identifiers
- Port configurations
- Timeout settings

### 2. Template-Based Configuration

**Decision**: Provide configuration templates with comprehensive documentation.

**Rationale**:

- **Onboarding**: New users can quickly understand available options
- **Documentation**: Templates serve as living documentation
- **Consistency**: Ensures consistent configuration across environments
- **Best Practices**: Templates include recommended settings

## Testing Strategy

### 1. Multi-Layer Testing Approach

**Decision**: Implement multiple testing layers for comprehensive validation.

**Rationale**:

- **Coverage**: Different tests validate different aspects of the system
- **Confidence**: Multiple validation approaches increase confidence
- **Debugging**: Different tests help isolate issues
- **Documentation**: Tests serve as executable documentation

**Testing Layers**:

1. **Unit Tests**: Individual component validation (`verify-requirements.sh`)
2. **Integration Tests**: End-to-end functionality (`test-deployment.sh`)
3. **Chaos Tests**: Failure scenario validation (`demo-failover.sh`)
4. **Manual Tests**: Interactive validation and debugging

### 2. Automated Health Checks

**Decision**: Implement comprehensive health checking at multiple levels.

**Rationale**:

- **Reliability**: Early detection of service issues
- **Automation**: Reduces manual monitoring overhead
- **Failover**: Enables automatic failover based on health status
- **Debugging**: Provides clear indication of service state

**Health Check Levels**:

- Docker Compose health checks
- Nginx upstream health monitoring
- Application-level health endpoints
- Script-based health validation

## Operational Considerations

### 1. Production Readiness

**Decision**: Design for production deployment from the start.

**Rationale**:

- **Scalability**: Architecture supports production workloads
- **Reliability**: Built-in failover and health monitoring
- **Monitoring**: Comprehensive logging and status reporting
- **Maintenance**: Easy updates and configuration changes

**Production Features**:

- Health-based routing
- Automatic failover
- Comprehensive logging
- Graceful degradation
- Easy configuration management

### 2. Developer Experience

**Decision**: Prioritize developer experience and ease of use.

**Rationale**:

- **Adoption**: Easy-to-use tools encourage adoption
- **Productivity**: Reduces time to deploy and test
- **Documentation**: Self-documenting scripts and clear output
- **Debugging**: Easy troubleshooting and issue resolution

**Developer Experience Features**:

- One-command deployment
- Interactive demonstrations
- Clear error messages
- Comprehensive testing tools
- Easy cleanup and reset

### 3. Observability and Monitoring

**Decision**: Build observability into the architecture.

**Rationale**:

- **Debugging**: Easy to identify issues and root causes
- **Performance**: Monitor system performance and behavior
- **Compliance**: Meet monitoring and logging requirements
- **Operations**: Enable effective operational management

**Observability Features**:

- Request tracing via headers
- Comprehensive logging
- Health check endpoints
- Service status reporting
- Failover event tracking

## Future Considerations

### Potential Enhancements

1. **Metrics Collection**: Add Prometheus metrics for monitoring
2. **Distributed Tracing**: Implement request tracing across services
3. **Configuration Management**: External configuration service integration
4. **Auto-scaling**: Dynamic scaling based on load
5. **Multi-Region**: Cross-region failover capabilities

### Scalability Considerations

1. **Horizontal Scaling**: Architecture supports multiple instances per pool
2. **Load Distribution**: Nginx can distribute load across multiple instances
3. **Resource Management**: Docker Compose supports resource limits
4. **Network Optimization**: Optimized proxy settings for performance

## Conclusion

This Blue/Green deployment architecture provides a robust, production-ready solution for zero-downtime deployments with comprehensive testing, monitoring, and operational capabilities. The design prioritizes reliability, developer experience, and operational excellence while maintaining simplicity and maintainability.

The modular script architecture ensures easy maintenance and extension, while the comprehensive testing strategy provides confidence in the system's behavior. The configuration management approach enables flexibility across different environments while maintaining consistency and best practices.
