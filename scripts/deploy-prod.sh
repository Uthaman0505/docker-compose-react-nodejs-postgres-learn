#!/bin/bash

# Production Deployment Script for Monorepo with Pre-built Images
# This script manages deployment using images from GitHub Container Registry

set -e  # Exit on any error

# Configuration
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env"
BACKUP_DIR="backups"
LOG_FILE="deploy-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${PURPLE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Display banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                   MONOREPO DEPLOYMENT                        ║"
    echo "║              GitHub Container Registry Images                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Docker Compose file '$COMPOSE_FILE' not found!"
        error "Make sure you're in the project root directory."
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        error "Environment file '$ENV_FILE' not found!"
        error "Copy .env.production to .env and update values."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH!"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed!"
        exit 1
    fi
    
    # Check if logged into GitHub Container Registry
    if ! docker system info | grep -q "ghcr.io" 2>/dev/null; then
        warning "You may not be logged into GitHub Container Registry"
        warning "Run: docker login ghcr.io -u YOUR_GITHUB_USERNAME"
    fi
    
    success "Prerequisites check passed"
}

# Validate image names in compose file
validate_images() {
    log "Validating image configurations..."
    
    if grep -q "YOUR_GITHUB_USERNAME" "$COMPOSE_FILE" || grep -q "YOUR_REPOSITORY_NAME" "$COMPOSE_FILE"; then
        error "Please update image names in $COMPOSE_FILE"
        error "Replace YOUR_GITHUB_USERNAME and YOUR_REPOSITORY_NAME with actual values"
        exit 1
    fi
    
    success "Image configuration validated"
}

# Create database backup
backup_database() {
    log "Creating database backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Check if database container is running
    if docker compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up\|running"; then
        BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
        
        if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U postgres -d production_db > "$BACKUP_FILE" 2>/dev/null; then
            success "Database backup created: $BACKUP_FILE"
        else
            warning "Failed to create database backup (container might not be ready)"
        fi
    else
        info "Database container not running, skipping backup"
    fi
}

# Health check function
health_check() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    log "Performing health check for $service..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" ps "$service" | grep -q "healthy\|Up"; then
            success "$service is healthy"
            return 0
        fi
        
        log "Waiting for $service to be healthy... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    error "$service failed health check after $max_attempts attempts"
    return 1
}

# Pull latest images
pull_images() {
    log "Pulling latest Docker images from GitHub Container Registry..."
    
    if docker compose -f "$COMPOSE_FILE" pull; then
        success "Successfully pulled latest images"
        
        # Show pulled images
        info "Pulled images:"
        docker compose -f "$COMPOSE_FILE" images
    else
        error "Failed to pull images"
        error "Check your GitHub Container Registry authentication"
        exit 1
    fi
}

# Deploy application
deploy() {
    log "Starting deployment..."
    
    # Stop existing containers gracefully
    log "Stopping existing containers..."
    docker compose -f "$COMPOSE_FILE" down --timeout 30
    
    # Start services
    log "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to start
    sleep 15
    
    # Check database health
    if ! health_check "postgres"; then
        error "Database health check failed"
        show_logs
        exit 1
    fi
    
    # Check server health
    if ! health_check "server"; then
        error "Server health check failed"
        show_logs
        exit 1
    fi
    
    # Check client health
    if ! health_check "client"; then
        error "Client health check failed"
        show_logs
        exit 1
    fi
    
    success "Deployment completed successfully!"
}

# Show application status
show_status() {
    log "Application Status:"
    echo ""
    docker compose -f "$COMPOSE_FILE" ps
    
    echo ""
    log "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    
    echo ""
    log "Image Information:"
    docker compose -f "$COMPOSE_FILE" images
}

# Show logs
show_logs() {
    log "Recent Application Logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=20
}

# Rollback function
rollback() {
    local tag=${1:-"previous"}
    
    warning "Rolling back to tag: $tag"
    
    if [ "$tag" = "previous" ]; then
        warning "Rollback requires specific image tag"
        warning "Usage: $0 rollback <tag>"
        warning "Example: $0 rollback v1.0.0"
        exit 1
    fi
    
    log "Updating compose file to use tag: $tag"
    
    # Create temporary compose file with rollback tag
    sed "s/:latest/:$tag/g" "$COMPOSE_FILE" > "${COMPOSE_FILE}.rollback"
    
    log "Deploying rollback version..."
    docker compose -f "${COMPOSE_FILE}.rollback" pull
    docker compose -f "$COMPOSE_FILE" down --timeout 30
    docker compose -f "${COMPOSE_FILE}.rollback" up -d
    
    # Cleanup
    rm "${COMPOSE_FILE}.rollback"
    
    success "Rollback completed"
}

# Cleanup old images
cleanup() {
    log "Cleaning up unused Docker images..."
    
    # Remove dangling images
    docker image prune -f
    
    # Show disk usage
    log "Docker disk usage:"
    docker system df
    
    success "Cleanup completed"
}

# Update images to specific tag
update_tag() {
    local tag=${1:-"latest"}
    
    log "Updating deployment to use tag: $tag"
    
    # Update compose file
    sed -i.bak "s/:latest/:$tag/g" "$COMPOSE_FILE"
    
    pull_images
    deploy
    
    success "Updated to tag: $tag"
}

# Main deployment function
main() {
    show_banner
    
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            validate_images
            backup_database
            pull_images
            deploy
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "backup")
            backup_database
            ;;
        "pull")
            check_prerequisites
            validate_images
            pull_images
            ;;
        "rollback")
            rollback "$2"
            ;;
        "cleanup")
            cleanup
            ;;
        "update")
            update_tag "$2"
            ;;
        "restart")
            log "Restarting services..."
            docker compose -f "$COMPOSE_FILE" restart
            show_status
            ;;
        "stop")
            log "Stopping services..."
            docker compose -f "$COMPOSE_FILE" down
            ;;
        *)
            echo "Usage: $0 {deploy|status|logs|backup|pull|rollback|cleanup|update|restart|stop}"
            echo ""
            echo "Commands:"
            echo "  deploy          - Full deployment with backup and health checks (default)"
            echo "  status          - Show current application status and resource usage"
            echo "  logs            - Show recent application logs"
            echo "  backup          - Create database backup only"
            echo "  pull            - Pull latest images from registry"
            echo "  rollback <tag>  - Rollback to specific image tag"
            echo "  cleanup         - Clean up unused Docker images"
            echo "  update <tag>    - Update to specific image tag"
            echo "  restart         - Restart all services"
            echo "  stop            - Stop all services"
            echo ""
            echo "Examples:"
            echo "  $0 deploy                    # Deploy latest images"
            echo "  $0 rollback v1.0.0          # Rollback to version 1.0.0"
            echo "  $0 update main-abc1234      # Update to specific commit"
            exit 1
            ;;
    esac
    
    log "=== Deployment Script Completed ==="
}

# Run main function with all arguments
main "$@"
