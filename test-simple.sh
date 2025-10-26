#!/bin/bash

echo "🚀 Starting Blue/Green Deployment Test"
echo "======================================"

# Check if user has docker access
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker permission issue. Please run:"
    echo "   sudo usermod -aG docker $USER"
    echo "   newgrp docker"
    echo "Then run this script again."
    exit 1
fi

# Clean up any existing containers
echo "Cleaning up any existing containers..."
docker-compose down 2>/dev/null || true

# Start services
echo "Starting services with Blue as active..."
BLUE_IMAGE=node:18-alpine GREEN_IMAGE=node:18-alpine docker-compose up -d

echo "Waiting for services to start..."
sleep 20

echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "🔵 Testing Baseline Routing (Should be Blue)"
echo "============================================"
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s http://localhost:8090/version 2>/dev/null | grep -o '"pool":"[^"]*' | cut -d'"' -f4 || echo "unavailable"
    sleep 1
done

echo ""
echo "🔍 Testing Direct Access"
echo "========================"
echo -n "Blue direct (8081): "
curl -s http://localhost:8081/healthz 2>/dev/null || echo "unavailable"
echo ""
echo -n "Green direct (8082): "
curl -s http://localhost:8082/healthz 2>/dev/null || echo "unavailable"

echo ""
echo "📝 Testing Headers"
echo "=================="
echo "Through Nginx (port 8090):"
curl -I -s http://localhost:8090/version 2>/dev/null | grep -i "x-app-pool\|x-release-id" || echo "No headers"

echo ""
echo "Direct to Blue (port 8081):"
curl -I -s http://localhost:8081/version 2>/dev/null | grep -i "x-app-pool\|x-release-id" || echo "No headers"

echo ""
echo "Direct to Green (port 8082):"
curl -I -s http://localhost:8082/version 2>/dev/null | grep -i "x-app-pool\|x-release-id" || echo "No headers"

echo ""
echo "🎯 Testing Chaos Endpoints"
echo "=========================="
echo "Blue chaos start (should return 500):"
curl -s -X POST http://localhost:8081/chaos/start 2>/dev/null || echo "unavailable"
echo ""
echo "Green chaos start (should return 500):"
curl -s -X POST http://localhost:8082/chaos/start 2>/dev/null || echo "unavailable"

echo ""
echo "✅ Basic setup complete!"
echo "   Nginx:  http://localhost:8090"
echo "   Blue:   http://localhost:8081"
echo "   Green:  http://localhost:8082"