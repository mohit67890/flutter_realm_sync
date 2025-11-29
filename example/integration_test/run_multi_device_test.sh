#!/bin/bash

# Multi-Device Sync Test Runner
# This script runs tests on two iOS simulators simultaneously to test real multi-client sync

set -e

echo "🚀 Multi-Device Sync Test Runner"
echo "================================="
echo ""

# Define simulator IDs (iPhone 14 Pro and iPhone SE)
DEVICE1="B759E3EE-491E-42D4-9A19-5ABEE278819F"  # iPhone 14 Pro
DEVICE2="FFDC4AB8-8E52-4435-8FDB-F11EBEFB62C6"  # iPhone SE (3rd gen)

# Get device names
DEVICE1_NAME=$(xcrun simctl list devices | grep "$DEVICE1" | sed 's/.*(\([^)]*\)).*/\1/' | head -1 | sed 's/ (.*//;s/.* //')
DEVICE2_NAME=$(xcrun simctl list devices | grep "$DEVICE2" | sed 's/.*(\([^)]*\)).*/\1/' | head -1 | sed 's/ (.*//;s/.* //')

echo "📱 Device 1: $DEVICE1_NAME ($DEVICE1)"
echo "📱 Device 2: $DEVICE2_NAME ($DEVICE2)"
echo ""

# Check if server is running
echo "🔍 Checking sync server..."
if ! curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "❌ Sync server is not running on localhost:3000"
    echo "   Start it with: cd sync-implementation && NODE_ENV=development npx ts-node server/index.ts"
    exit 1
fi
echo "✅ Sync server is running"
echo ""

# Boot simulators if not already running
echo "🔌 Starting simulators..."
xcrun simctl boot "$DEVICE1" 2>/dev/null || echo "   Device 1 already booted"
xcrun simctl boot "$DEVICE2" 2>/dev/null || echo "   Device 2 already booted"
sleep 2
echo "✅ Simulators ready"
echo ""

# Build the app once
echo "🔨 Building app..."
cd "$(dirname "$0")/.."
flutter build ios --simulator --debug > /tmp/flutter_build.log 2>&1 &
BUILD_PID=$!

# Show progress
while kill -0 $BUILD_PID 2>/dev/null; do
    echo -n "."
    sleep 2
done
wait $BUILD_PID
BUILD_STATUS=$?

if [ $BUILD_STATUS -ne 0 ]; then
    echo ""
    echo "❌ Build failed. Check /tmp/flutter_build.log"
    tail -20 /tmp/flutter_build.log
    exit 1
fi
echo ""
echo "✅ Build complete"
echo ""

# Run test on Device 1 (background)
echo "▶️  Starting test on Device 1 ($DEVICE1_NAME)..."
flutter test integration_test/multi_client_sync_test.dart \
    --device-id="$DEVICE1" \
    > /tmp/device1_test.log 2>&1 &
DEVICE1_PID=$!

sleep 5

# Run test on Device 2 (background)
echo "▶️  Starting test on Device 2 ($DEVICE2_NAME)..."
flutter test integration_test/multi_client_sync_test.dart \
    --device-id="$DEVICE2" \
    > /tmp/device2_test.log 2>&1 &
DEVICE2_PID=$!

echo ""
echo "⏳ Tests running on both devices..."
echo "   Device 1 logs: /tmp/device1_test.log"
echo "   Device 2 logs: /tmp/device2_test.log"
echo ""
echo "   Monitor with: tail -f /tmp/device1_test.log"
echo "                 tail -f /tmp/device2_test.log"
echo ""

# Wait for both tests to complete
echo "⏰ Waiting for tests to complete (max 2 minutes)..."

TIMEOUT=120
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $TIMEOUT ]; do
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    
    # Check if both processes are still running
    if ! kill -0 $DEVICE1_PID 2>/dev/null && ! kill -0 $DEVICE2_PID 2>/dev/null; then
        break
    fi
    
    echo "   Still running... ($ELAPSED seconds elapsed)"
done

# Kill any remaining processes
kill $DEVICE1_PID 2>/dev/null || true
kill $DEVICE2_PID 2>/dev/null || true

echo ""
echo "📊 Test Results"
echo "==============="
echo ""

# Check Device 1 results
echo "📱 Device 1 ($DEVICE1_NAME):"
if grep -q "All tests passed" /tmp/device1_test.log; then
    echo "   ✅ All tests passed"
    grep "TEST.*PASSED" /tmp/device1_test.log | tail -5
elif grep -q "Some tests failed" /tmp/device1_test.log; then
    echo "   ❌ Some tests failed"
    grep -E "(TEST.*PASSED|TEST.*FAILED|failed)" /tmp/device1_test.log | tail -10
else
    echo "   ⚠️  Unknown status"
fi
echo ""

# Check Device 2 results
echo "📱 Device 2 ($DEVICE2_NAME):"
if grep -q "All tests passed" /tmp/device2_test.log; then
    echo "   ✅ All tests passed"
    grep "TEST.*PASSED" /tmp/device2_test.log | tail -5
elif grep -q "Some tests failed" /tmp/device2_test.log; then
    echo "   ❌ Some tests failed"
    grep -E "(TEST.*PASSED|TEST.*FAILED|failed)" /tmp/device2_test.log | tail -10
else
    echo "   ⚠️  Unknown status"
fi
echo ""

# Show sync events
echo "🔄 Sync Events:"
echo "Device 1 received events:"
grep "📨.*Received" /tmp/device1_test.log 2>/dev/null | wc -l | xargs echo "  "
echo "Device 2 received events:"
grep "📨.*Received" /tmp/device2_test.log 2>/dev/null | wc -l | xargs echo "  "
echo ""

echo "✅ Multi-device test complete!"
echo ""
echo "View full logs:"
echo "  Device 1: cat /tmp/device1_test.log"
echo "  Device 2: cat /tmp/device2_test.log"
