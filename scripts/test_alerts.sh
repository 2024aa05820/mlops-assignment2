#!/bin/bash
# =============================================================================
# Test Alerts Script - MLOps Assignment 2
# Tests the complete alert flow: Prometheus -> AlertManager -> Email
# =============================================================================

set -e

echo "========================================="
echo "🔔 MLOps Alert Testing Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if services are accessible
echo -e "${BLUE}1️⃣  Checking Service Connectivity${NC}"
echo "----------------------------------------"

# Check Prometheus
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Prometheus: http://localhost:9090${NC}"
else
    echo -e "${RED}❌ Prometheus not accessible at http://localhost:9090${NC}"
    echo "   Run: make kind-full"
    exit 1
fi

# Check AlertManager
if curl -s http://localhost:9093/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✅ AlertManager: http://localhost:9093${NC}"
else
    echo -e "${YELLOW}⚠️  AlertManager not accessible at http://localhost:9093${NC}"
    echo "   You may need to recreate the Kind cluster with new port mappings"
fi

# Check API
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ API: http://localhost:8000${NC}"
else
    echo -e "${RED}❌ API not accessible at http://localhost:8000${NC}"
fi

echo ""
echo -e "${BLUE}2️⃣  Checking Prometheus Alert Rules${NC}"
echo "----------------------------------------"

RULES=$(curl -s http://localhost:9090/api/v1/rules 2>/dev/null)
if echo "$RULES" | python3 -c "import sys,json; d=json.load(sys.stdin); rules=[r['name'] for g in d.get('data',{}).get('groups',[]) for r in g.get('rules',[])]; print(f'Found {len(rules)} alert rules:'); [print(f'  - {r}') for r in rules]" 2>/dev/null; then
    echo ""
else
    echo -e "${RED}❌ Could not fetch alert rules${NC}"
fi

echo ""
echo -e "${BLUE}3️⃣  Checking Current Alert Status${NC}"
echo "----------------------------------------"

# Check Prometheus alerts
echo "Prometheus Alerts:"
curl -s http://localhost:9090/api/v1/alerts 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    alerts = d.get('data', {}).get('alerts', [])
    firing = [a for a in alerts if a.get('state') == 'firing']
    pending = [a for a in alerts if a.get('state') == 'pending']
    print(f'  Firing: {len(firing)}, Pending: {len(pending)}')
    for a in firing:
        print(f'  🔴 {a[\"labels\"][\"alertname\"]} ({a[\"labels\"].get(\"severity\", \"unknown\")})')
    for a in pending:
        print(f'  🟡 {a[\"labels\"][\"alertname\"]} (pending)')
except:
    print('  Could not parse response')
" 2>/dev/null || echo "  Could not connect to Prometheus"

echo ""
echo "AlertManager Alerts:"
curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | python3 -c "
import sys, json
try:
    alerts = json.load(sys.stdin)
    if alerts:
        print(f'  Active alerts: {len(alerts)}')
        for a in alerts:
            print(f'  🔔 {a[\"labels\"][\"alertname\"]} - {a[\"status\"][\"state\"]}')
    else:
        print('  ✅ No active alerts')
except:
    print('  Could not parse response')
" 2>/dev/null || echo "  Could not connect to AlertManager"

echo ""
echo -e "${BLUE}4️⃣  Checking AlertManager Configuration${NC}"
echo "----------------------------------------"

curl -s http://localhost:9093/api/v2/status 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    config = d.get('config', {}).get('original', '')
    if 'smtp' in config:
        print('  ✅ SMTP configured')
        if 'your-email@gmail.com' in config or 'your-app-password' in config:
            print('  ⚠️  WARNING: Default placeholder values detected!')
            print('  📝 Update deploy/k8s/alertmanager.yaml with your Gmail credentials')
        else:
            print('  ✅ Custom email configured')
    else:
        print('  ❌ SMTP not configured')
except Exception as e:
    print(f'  Could not parse: {e}')
" 2>/dev/null || echo "  Could not connect to AlertManager"

echo ""
echo -e "${BLUE}5️⃣  Generate Test Traffic${NC}"
echo "----------------------------------------"

if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "Making 10 prediction requests..."
    for i in {1..10}; do
        # Try to make a prediction (may fail if no test image)
        curl -s -X POST http://localhost:8000/predict \
            -F "file=@data/raw/test/cat/cat.1001.jpg" > /dev/null 2>&1 || true
        echo -n "."
    done
    echo " Done!"
    
    echo ""
    echo "Current metrics:"
    curl -s http://localhost:8000/metrics 2>/dev/null | grep -E "^(predictions_total|prediction_errors)" | head -5
else
    echo "API not accessible, skipping traffic generation"
fi

echo ""
echo "========================================="
echo -e "${GREEN}🎉 Alert Test Complete!${NC}"
echo "========================================="
echo ""
echo "📊 View Prometheus Alerts: http://localhost:9090/alerts"
echo "🔔 View AlertManager:      http://localhost:9093"
echo "📈 View Grafana Dashboard: http://localhost:3000"
echo ""
echo "💡 To trigger a test alert, you can:"
echo "   1. Scale down pods: kubectl scale deployment cats-dogs-api --replicas=0 -n mlops"
echo "   2. Wait 5 minutes for PodNotReady alert"
echo "   3. Scale back up: kubectl scale deployment cats-dogs-api --replicas=2 -n mlops"
echo ""

