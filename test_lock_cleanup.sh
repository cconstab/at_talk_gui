#!/bin/bash
# Test script to verify lock file cleanup on TUI exit

echo "🧪 Testing TUI lock file cleanup..."

# Create a temp directory for testing
TEST_DIR="/tmp/attalk_lock_test"
mkdir -p "$TEST_DIR"

echo "📁 Test directory: $TEST_DIR"

# Function to check for lock files
check_lock_files() {
    local locks=$(find "$TEST_DIR" -name "*.lock" 2>/dev/null | wc -l)
    echo "🔍 Lock files found: $locks"
    if [ $locks -gt 0 ]; then
        echo "📄 Lock files:"
        find "$TEST_DIR" -name "*.lock" -exec ls -la {} \; 2>/dev/null
    fi
    return $locks
}

echo "📊 Initial state:"
check_lock_files

echo ""
echo "🚀 Starting TUI with test storage path..."
echo "   (This will fail due to missing atsign, but should create lock file)"
echo "   Press Ctrl+C or type '/exit' to test cleanup"
echo ""

# Run TUI with test storage path
cd /Users/cconstab/Documents/GitHub/cconstab/at_talk_gui
./test_tui -a @test_atsign -t @other_atsign -s "$TEST_DIR" || true

echo ""
echo "📊 After TUI exit:"
check_lock_files

# Cleanup
rm -rf "$TEST_DIR"
rm -f test_tui

if [ $? -eq 0 ]; then
    echo "✅ Lock file was cleaned up properly!"
else
    echo "❌ Lock file was NOT cleaned up!"
fi

echo "🧹 Test cleanup complete"
