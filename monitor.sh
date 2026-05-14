#!/bin/bash

################################################################################
# 📊 AUTONOMOUS SOC - MONITORING & DIAGNOSTICS SCRIPT
# Displays system status, logs, and performance metrics
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}▶ $1${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

print_header "📊 AUTONOMOUS SOC - SYSTEM DIAGNOSTICS"

# Check Docker
print_section "Docker Status"
if docker ps > /dev/null 2>&1; then
    print_success "Docker is running"
else
    print_error "Docker is not running"
    exit 1
fi

# Container Status
print_section "Container Status"
docker-compose ps

# Network Check
print_section "Network Connectivity"
echo "Checking API (http://localhost:8000/health)..."
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Backend API is accessible"
    curl -s http://localhost:8000/health | python -m json.tool 2>/dev/null || echo "..."
else
    print_error "Backend API is not responding"
fi

echo ""
echo "Checking Frontend (http://localhost:3000)..."
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Frontend is accessible"
else
    print_error "Frontend is not responding"
fi

# Database Connection
print_section "Database Status"
if docker-compose exec -T postgres pg_isready -U soc_user > /dev/null 2>&1; then
    print_success "PostgreSQL is running"
    # Get database size
    db_size=$(docker-compose exec -T postgres psql -U soc_user -d autonomous_soc -t -c "SELECT pg_size_pretty(pg_database_size('autonomous_soc'));" 2>/dev/null || echo "Unknown")
    echo "Database size: $db_size"
else
    print_error "PostgreSQL is not responding"
fi

# Redis Connection
print_section "Redis Status"
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    print_success "Redis is running"
    memory=$(docker-compose exec -T redis redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d: -f2 || echo "Unknown")
    echo "Redis memory usage: $memory"
else
    print_error "Redis is not responding"
fi

# Recent Logs
print_section "Recent Backend Logs (Last 10 lines)"
docker-compose logs --tail=10 backend 2>/dev/null || echo "No logs available"

print_section "Recent Frontend Logs (Last 10 lines)"
docker-compose logs --tail=10 frontend 2>/dev/null || echo "No logs available"

# Service Resources
print_section "Container Resource Usage"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Unable to retrieve resource usage"

# Summary
print_header "📋 DIAGNOSTICS SUMMARY"

echo -e "${GREEN}System Information:${NC}"
echo "  Containers:  $(docker-compose ps -q | wc -l) running"
echo "  OS:          $(uname -s)"
echo "  Docker:      $(docker --version)"
echo ""

echo -e "${GREEN}Access URLs:${NC}"
echo "  Frontend:    ${BLUE}http://localhost:3000${NC}"
echo "  API Docs:    ${BLUE}http://localhost:8000/api/docs${NC}"
echo "  Health:      ${BLUE}http://localhost:8000/health${NC}"
echo ""

echo -e "${GREEN}Next Steps:${NC}"
echo "  - View full logs:  docker-compose logs -f"
echo "  - Restart service: docker-compose restart [service_name]"
echo "  - Cleanup all:     ./cleanup.sh"
echo ""

print_header "✨ DIAGNOSTICS COMPLETE"
