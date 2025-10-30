#!/bin/bash

# Ubuntu Server Docker Setup Script
# Comprehensive Docker installation with error handling and validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if user has sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges. Please ensure your user can run sudo commands."
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    if ! command -v lsb_release &> /dev/null; then
        log "Installing lsb-release for version detection..."
        sudo apt update -qq
        sudo apt install -y lsb-release
    fi
    
    local ubuntu_version=$(lsb_release -rs)
    local ubuntu_codename=$(lsb_release -cs)
    
    log "Detected Ubuntu version: $ubuntu_version ($ubuntu_codename)"
    
    # Check if version is supported (Ubuntu 20.04+)
    if [[ $(echo "$ubuntu_version" | cut -d. -f1) -lt 20 ]]; then
        warning "Ubuntu version $ubuntu_version may not be fully supported. Continuing anyway..."
    fi
}

# Function to update system packages
update_system() {
    log "Updating system packages..."
    if ! sudo apt update -y; then
        error "Failed to update package lists"
        exit 1
    fi
    
    log "Upgrading system packages..."
    if ! sudo apt upgrade -y; then
        error "Failed to upgrade system packages"
        exit 1
    fi
    
    success "System packages updated successfully"
}

# Function to install prerequisites
install_prerequisites() {
    log "Installing Docker prerequisites..."
    
    local packages=("ca-certificates" "curl" "gnupg" "lsb-release")
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "Installing $package..."
            if ! sudo apt install -y "$package"; then
                error "Failed to install $package"
                exit 1
            fi
        else
            log "$package is already installed"
        fi
    done
    
    success "Prerequisites installed successfully"
}

# Function to add Docker GPG key
add_docker_gpg_key() {
    log "Adding Docker GPG key..."
    
    # Create directory for keyrings
    if ! sudo install -m 0755 -d /etc/apt/keyrings; then
        error "Failed to create keyrings directory"
        exit 1
    fi
    
    # Download and add GPG key
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        error "Failed to download and add Docker GPG key"
        exit 1
    fi
    
    # Set proper permissions
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    success "Docker GPG key added successfully"
}

# Function to add Docker repository
add_docker_repository() {
    log "Adding Docker repository..."
    
    local arch=$(dpkg --print-architecture)
    local codename=$(lsb_release -cs)
    
    log "Architecture: $arch, Codename: $codename"
    
    # Add Docker repository
    local repo_line="deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"
    
    if ! echo "$repo_line" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        error "Failed to add Docker repository"
        exit 1
    fi
    
    # Update package lists
    if ! sudo apt update; then
        error "Failed to update package lists after adding Docker repository"
        exit 1
    fi
    
    success "Docker repository added successfully"
}

# Function to install Docker
install_docker() {
    log "Installing Docker packages..."
    
    # Check available Docker versions
    log "Available Docker versions:"
    apt-cache policy docker-ce | head -10
    
    # Install Docker packages
    local packages=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    
    for package in "${packages[@]}"; do
        log "Installing $package..."
        if ! sudo apt install -y "$package"; then
            error "Failed to install $package"
            exit 1
        fi
    done
    
    success "Docker packages installed successfully"
}

# Function to configure Docker
configure_docker() {
    log "Configuring Docker..."
    
    # Add user to docker group
    if ! groups "$USER" | grep -q docker; then
        log "Adding user $USER to docker group..."
        if ! sudo usermod -aG docker "$USER"; then
            error "Failed to add user to docker group"
            exit 1
        fi
        success "User added to docker group"
        
        # Apply group changes by switching to docker group
        log "Applying group changes with 'newgrp docker'..."
        
        # Use 'sg' command to apply group changes in current shell
        log "Executing commands with docker group..."
        if ! sg docker -c "exit"; then
            warning "Could not switch to docker group. You may need to log out and log back in."
        fi
        
        success "Group changes applied"
    else
        log "User is already in docker group"
    fi
    
    # Enable and start Docker service
    log "Enabling Docker service..."
    if ! sudo systemctl enable docker; then
        error "Failed to enable Docker service"
        exit 1
    fi
    
    log "Starting Docker service..."
    if ! sudo systemctl start docker; then
        error "Failed to start Docker service"
        exit 1
    fi
    
    success "Docker service configured successfully"
}

# Function to verify Docker installation
verify_docker_installation() {
    log "Verifying Docker installation..."
    
    # Check Docker service status first
    if ! sudo systemctl is-active --quiet docker; then
        error "Docker service is not running"
        return 1
    fi
    
    # Check Docker version (without sudo to verify group permissions)
    if ! docker --version > /dev/null 2>&1; then
        # If fails without sudo, test with sudo for compatibility
        if ! sudo docker --version; then
            error "Docker command not found"
            return 1
        fi
        warning "Docker requires sudo. Group changes may need a new session."
    else
        success "Docker accessible without sudo"
    fi
    
    # Check Docker Compose version
    if ! docker compose version > /dev/null 2>&1; then
        if ! sudo docker compose version > /dev/null 2>&1; then
            error "Docker Compose command not found"
            return 1
        fi
    fi
    
    # Test Docker with hello-world
    log "Testing Docker with hello-world container..."
    if ! docker run --rm hello-world > /dev/null 2>&1; then
        # Fallback to sudo if needed
        if ! sudo docker run --rm hello-world > /dev/null 2>&1; then
            error "Docker hello-world test failed"
            return 1
        fi
        warning "Docker run requires sudo. Group changes may need a new session."
    else
        success "Docker test passed without sudo"
    fi
    
    success "Docker installation verified successfully"
}

# Function to show post-installation instructions
show_post_install_instructions() {
    echo ""
    echo -e "${GREEN}🎉 Docker installation completed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Post-installation instructions:${NC}"
    echo ""
    echo "1. If group changes were applied with 'newgrp', test Docker now:"
    echo "   docker --version"
    echo "   docker compose version"
    echo "   docker run --rm hello-world"
    echo ""
    echo "2. If you need to apply group changes manually:"
    echo "   newgrp docker"
    echo ""
    echo "3. Or log out and log back in:"
    echo "   logout"
    echo ""
    echo "4. Optional: Configure Docker daemon settings:"
    echo "   sudo mkdir -p /etc/docker"
    echo "   sudo nano /etc/docker/daemon.json"
    echo ""
    echo -e "${BLUE}📚 Useful Docker commands:${NC}"
    echo "   docker ps                    # List running containers"
    echo "   docker images               # List images"
    echo "   docker compose up -d        # Start services"
    echo "   docker compose down         # Stop services"
    echo "   docker system prune         # Clean up unused resources"
    echo ""
    echo -e "${GREEN}✅ Your Ubuntu server is now ready for Docker!${NC}"
}

# Function to handle cleanup on error
cleanup_on_error() {
    error "Installation failed. Cleaning up..."
    
    # Stop Docker service if it was started
    if sudo systemctl is-active --quiet docker; then
        sudo systemctl stop docker
    fi
    
    # Remove Docker packages if installation was incomplete
    if dpkg -l | grep -q docker-ce; then
        sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    fi
    
    # Remove Docker repository
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        sudo rm -f /etc/apt/sources.list.d/docker.list
    fi
    
    # Remove Docker GPG key
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        sudo rm -f /etc/apt/keyrings/docker.gpg
    fi
    
    error "Cleanup completed. Please check the error messages above and try again."
}

# Main installation function
main() {
    echo -e "${BLUE}🐳 Ubuntu Server Docker Setup${NC}"
    echo "=================================="
    echo ""
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Pre-installation checks
    log "Performing pre-installation checks..."
    check_root
    check_sudo
    check_ubuntu_version
    
    # Installation steps
    update_system
    install_prerequisites
    add_docker_gpg_key
    add_docker_repository
    install_docker
    configure_docker
    
    # Verification
    if verify_docker_installation; then
        show_post_install_instructions
    else
        error "Docker installation verification failed"
        exit 1
    fi
}

# Run main function
main "$@"
