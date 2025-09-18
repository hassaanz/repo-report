#!/bin/bash

# Simple bash script to test the server functionality
# This is a simplified version of the TypeScript test

set -e

SERVER_URL=${SERVER_URL:-"http://localhost:3000"}
TTL=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test HTML content
TEST_CONTENT='<!DOCTYPE html>
<html><head><title>Test Report</title></head>
<body><h1>Test Git History Report</h1>
<p>Total Commits: 42</p><p>Generated: '$(date)'</p></body></html>'

echo -e "${BLUE}🧪 Testing Git History Report Server${NC}"
echo -e "Server: $SERVER_URL"
echo -e "TTL: $TTL seconds\n"

# Step 1: Health check
echo -e "${BLUE}Step 0: Health check...${NC}"
if curl -s -f "$SERVER_URL/health" > /dev/null; then
    echo -e "${GREEN}✅ Server is healthy${NC}"
else
    echo -e "${RED}❌ Server health check failed${NC}"
    echo -e "${YELLOW}Make sure the server is running at $SERVER_URL${NC}"
    exit 1
fi

# Step 2: Create report
echo -e "\n${BLUE}Step 1: Creating report...${NC}"
RESPONSE=$(curl -s -X POST "$SERVER_URL/api/reports" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$TEST_CONTENT" | jq -R -s .), \"ttl\": $TTL}")

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create report${NC}"
    exit 1
fi

# Extract report hash from response
REPORT_HASH=$(echo "$RESPONSE" | jq -r '.reportHash')
REPORT_URL=$(echo "$RESPONSE" | jq -r '.url')

if [ "$REPORT_HASH" = "null" ] || [ -z "$REPORT_HASH" ]; then
    echo -e "${RED}❌ No report hash received${NC}"
    echo "Response: $RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Report created successfully${NC}"
echo -e "   Hash: ${CYAN}$REPORT_HASH${NC}"
echo -e "   URL: ${CYAN}$REPORT_URL${NC}"

# Step 3: Retrieve report
echo -e "\n${BLUE}Step 2: Retrieving report...${NC}"
RETRIEVED_CONTENT=$(curl -s "$SERVER_URL/r/$REPORT_HASH")

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to retrieve report${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Report retrieved successfully${NC}"

# Step 4: Validate content (basic check)
echo -e "\n${BLUE}Step 3: Validating content...${NC}"
if echo "$RETRIEVED_CONTENT" | grep -q "Test Git History Report"; then
    echo -e "${GREEN}✅ Content validation passed${NC}"
else
    echo -e "${RED}❌ Content validation failed${NC}"
    echo "Retrieved content does not contain expected text"
    exit 1
fi

# Step 5: Wait for expiry
echo -e "\n${BLUE}Step 4: Waiting for expiry ($(($TTL + 1)) seconds)...${NC}"
for i in $(seq $(($TTL + 1)) -1 1); do
    echo -ne "\r⏳ Waiting... $i seconds remaining"
    sleep 1
done
echo -e "\r⏳ Wait complete!                    "

# Step 6: Verify expiry
echo -e "\n${BLUE}Step 5: Verifying report has expired...${NC}"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null "$SERVER_URL/r/$REPORT_HASH")

if [ "$HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✅ Report correctly expired (404)${NC}"
else
    echo -e "${RED}❌ Report should have expired but returned: $HTTP_CODE${NC}"
    exit 1
fi

# Success
echo -e "\n${'='*60}"
echo -e "${GREEN}🎉 All tests passed! Server functionality is working correctly.${NC}"