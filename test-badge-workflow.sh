#!/bin/bash

# Test Badge Workflow - Demonstrates the complete badge generation process
# This script shows how to generate a report and use the badge in a GitHub README

set -euo pipefail

echo "🧪 Testing Badge Generation Workflow"
echo "=================================="
echo ""

echo "1. Generating git report..."
URL=$(./scripts/generate-and-upload.sh --preset today --quiet)
echo "   ✅ Report URL: $URL"

echo ""
echo "2. Extracting badge URL..."
HASH=$(echo "$URL" | sed 's/.*\/r\///')
BADGE_URL="${URL%/r/*}/api/reports/$HASH/badge"
echo "   ✅ Badge URL: $BADGE_URL"

echo ""
echo "3. Testing badge endpoint..."
curl -s "$BADGE_URL" -o workflow-test-badge.png
if [ -f workflow-test-badge.png ]; then
    SIZE=$(ls -lh workflow-test-badge.png | awk '{print $5}')
    echo "   ✅ Badge generated successfully ($SIZE)"
else
    echo "   ❌ Badge generation failed"
    exit 1
fi

echo ""
echo "4. GitHub README Integration:"
echo ""
echo "   Add this line to your README.md:"
echo "   ![Git Activity]($BADGE_URL)"
echo ""
echo "   Or use HTML for custom sizing:"
echo "   <img src=\"$BADGE_URL\" width=\"320\" alt=\"Git Activity Badge\">"
echo ""

echo "5. Report Access:"
echo "   📊 View full report: $URL"
echo "   🏷️  View badge: $BADGE_URL"
echo ""

echo "✅ Badge workflow test completed successfully!"
echo "   - Report generated and uploaded ✓"
echo "   - Badge URL extracted ✓"
echo "   - Badge image generated ✓"
echo "   - Ready for GitHub integration ✓"
echo ""
echo "💡 Tip: Both URLs have the same expiration time as configured in your upload settings."