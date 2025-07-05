#!/bin/bash

# Script to clean up DEBUG print statements and other cleanup tasks

echo "🧹 Starting repository cleanup..."

# Remove DEBUG print statements but preserve important ones
echo "📝 Removing DEBUG print statements..."

# Use a safer approach with sed
find lib -name "*.dart" -type f -exec sed -i '' '/print.*DEBUG:/d' {} \;

echo "🔍 Checking for remaining DEBUG statements..."
grep -r "DEBUG:" lib/ || echo "✅ No DEBUG statements found"

echo "📝 Removing excessive print statements (but keeping important ones)..."

# Let's also clean up some obvious print statements that are just noise
find lib -name "*.dart" -type f -exec sed -i '' '/print.*Raw notification:/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*Raw value:/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*Key:/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*📨/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*💬/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*🔄/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*✅/d' {} \;
find lib -name "*.dart" -type f -exec sed -i '' '/print.*❌/d' {} \;

echo "🔧 Running dart analyze to check for issues..."
dart analyze --no-fatal-warnings

echo "✅ Cleanup completed!"
