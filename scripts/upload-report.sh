#!/bin/bash

# Git History Report Uploader
# Accepts piped input and sends it to the server to generate a unique link
# Usage: cat report.html | ./upload-report.sh
#        echo "content" | ./upload-report.sh --ttl 7200
#        ./git-history-report.sh --preset today --format html | ./upload-report.sh

set -euo pipefail

# Default configuration
SERVER_URL=${GIT_REPORT_SERVER_URL:-"http://localhost:3001"}
DEFAULT_TTL=3600  # 1 hour
VERBOSE=false
QUIET=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << EOF
Git History Report Uploader

Accepts HTML content via stdin and uploads it to the Git History Report Server.
Also provides a badge URL for GitHub README integration.

USAGE:
    cat report.html | $0 [OPTIONS]
    echo "<html>...</html>" | $0 [OPTIONS]
    ./git-history-report.sh --format html | $0 [OPTIONS]

OPTIONS:
    -t, --ttl SECONDS       Time to live in seconds (default: 3600, max: 86400)
    -s, --server URL        Server URL (default: \$GIT_REPORT_SERVER_URL or http://localhost:3001)
    -v, --verbose           Show detailed output
    -q, --quiet             Suppress all output except the final URL
    -h, --help              Show this help message

EXAMPLES:
    # Upload a pre-generated report
    cat weekly-report.html | $0

    # Upload with custom TTL (2 hours)
    cat report.html | $0 --ttl 7200

    # Generate and upload in one command
    ./git-history-report.sh --preset last-week --format html | $0 --verbose

    # Use custom server
    export GIT_REPORT_SERVER_URL="https://reports.company.com"
    cat report.html | $0

    # Get badge URL for GitHub README
    URL=\$(cat report.html | $0 --quiet)
    HASH=\$(echo "\$URL" | sed 's/.*\\/r\\///')
    echo "Badge: \${URL%/r/*}/api/reports/\$HASH/badge"

ENVIRONMENT VARIABLES:
    GIT_REPORT_SERVER_URL   Default server URL (overrides built-in default)

EXIT CODES:
    0   Success
    1   Invalid arguments or usage
    2   Server error or network issue
    3   Content validation failed

EOF
}

# Logging functions
log_error() {
    [ "$QUIET" != "true" ] && echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    [ "$QUIET" != "true" ] && echo -e "${GREEN}✅ $1${NC}" >&2
}

log_info() {
    if [ "${VERBOSE:-false}" = "true" ]; then
        echo -e "${BLUE}ℹ️  $1${NC}" >&2
    fi
}

log_warning() {
    [ "$QUIET" != "true" ] && echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

# Parse command line arguments
parse_args() {
    TTL=$DEFAULT_TTL
    QUIET=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--ttl)
                TTL="$2"
                if ! [[ "$TTL" =~ ^[0-9]+$ ]] || [ "$TTL" -le 0 ] || [ "$TTL" -gt 86400 ]; then
                    log_error "Invalid TTL: $TTL. Must be a positive integer ≤ 86400 (24 hours)"
                    exit 1
                fi
                shift 2
                ;;
            -s|--server)
                SERVER_URL="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                VERBOSE=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Check if stdin is available
check_stdin() {
    if [ -t 0 ]; then
        log_error "No input detected. This script requires piped input."
        log_error "Usage: cat report.html | \$0"
        log_error "   or: ./git-history-report.sh --format html | \$0"
        exit 1
    fi
}

# Read and validate input
read_input() {
    log_info "Reading input from stdin..."

    # Read all input
    INPUT_CONTENT=$(cat)

    # Validate content
    if [ -z "$INPUT_CONTENT" ]; then
        log_error "Empty input received"
        exit 3
    fi

    # Check if it looks like HTML
    if ! echo "$INPUT_CONTENT" | grep -q "<html\|<!DOCTYPE"; then
        log_warning "Input doesn't appear to be HTML content"
        log_info "Content preview: $(echo "$INPUT_CONTENT" | head -c 100)..."
    fi

    INPUT_SIZE=$(echo -n "$INPUT_CONTENT" | wc -c | tr -d ' ')
    log_info "Input size: $INPUT_SIZE bytes"
}

# Upload content to server
upload_to_server() {
    log_info "Uploading to server: $SERVER_URL"
    log_info "TTL: $TTL seconds ($(($TTL / 60)) minutes)"

    # Escape JSON content properly
    ESCAPED_CONTENT=$(echo "$INPUT_CONTENT" | jq -Rs .)

    # Create JSON payload
    JSON_PAYLOAD="{\"content\": $ESCAPED_CONTENT, \"ttl\": $TTL}"

    # Upload to server
    RESPONSE=$(curl -s -w "%{http_code}" -o response.tmp --max-time 30 -X POST "$SERVER_URL/api/reports" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD" 2>/dev/null)

    HTTP_CODE=$(echo "$RESPONSE" | tail -c 4)

    if [ "$HTTP_CODE" = "201" ]; then
        # Parse successful response
        REPORT_DATA=$(cat response.tmp)
        REPORT_HASH=$(echo "$REPORT_DATA" | jq -r '.reportHash')
        REPORT_URL=$(echo "$REPORT_DATA" | jq -r '.url')
        EXPIRES_AT=$(echo "$REPORT_DATA" | jq -r '.expiresAt')

        # Calculate expiry time
        EXPIRES_DATE=$(date -d "@$EXPIRES_AT" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$EXPIRES_AT" '+%Y-%m-%d %H:%M:%S')

        log_success "Report uploaded successfully!"
        log_info "Report Hash: $REPORT_HASH"
        log_info "Expires: $EXPIRES_DATE"

        # Output the full URLs (this is the main output)
        FULL_URL="$SERVER_URL$REPORT_URL"
        BADGE_DEFAULT="$SERVER_URL/api/reports/$REPORT_HASH/badge"
        BADGE_WEEKLY="$SERVER_URL/api/reports/$REPORT_HASH/badge/weekly"
        BADGE_MONTHLY="$SERVER_URL/api/reports/$REPORT_HASH/badge/monthly"

        echo "$FULL_URL"

        # Show badge URLs in verbose mode or as info
        if [ "$VERBOSE" = "true" ]; then
            log_info "Default Badge: $BADGE_DEFAULT"
            log_info "Weekly Badge: $BADGE_WEEKLY"
            log_info "Monthly Badge: $BADGE_MONTHLY"
        elif [ "$QUIET" != "true" ]; then
            echo -e "${CYAN}🏷️  Badges: $BADGE_DEFAULT${NC}" >&2
            echo -e "${CYAN}📈  Weekly: $BADGE_WEEKLY${NC}" >&2
            echo -e "${CYAN}📊  Monthly: $BADGE_MONTHLY${NC}" >&2
        fi

    elif [ "$HTTP_CODE" = "400" ]; then
        ERROR_MSG=$(cat response.tmp | jq -r '.message // "Bad request"')
        log_error "Server rejected request: $ERROR_MSG"
        exit 3
    elif [ "$HTTP_CODE" = "000" ]; then
        log_error "Could not connect to server at $SERVER_URL"
        log_error "Make sure the server is running and accessible"
        exit 2
    else
        ERROR_MSG=$(cat response.tmp | jq -r '.message // "Unknown error"' 2>/dev/null || echo "HTTP $HTTP_CODE")
        log_error "Server error: $ERROR_MSG"
        exit 2
    fi

    # Cleanup
    rm -f response.tmp
}

# Test server connectivity
test_server() {
    log_info "Testing server connectivity..."

    if curl -s -f --max-time 5 "$SERVER_URL/health" > /dev/null; then
        log_info "Server is accessible and healthy"
    else
        log_warning "Server health check failed, but continuing anyway..."
    fi
}

# Main execution
main() {
    parse_args "$@"
    check_stdin
    read_input

    if [ "$VERBOSE" = "true" ]; then
        test_server
    fi

    upload_to_server
}

# Handle interrupts gracefully
trap 'log_error "Upload interrupted"; rm -f response.tmp; exit 130' INT TERM

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Please install jq."
    log_error "  macOS: brew install jq"
    log_error "  Ubuntu/Debian: apt-get install jq"
    log_error "  CentOS/RHEL: yum install jq"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    log_error "curl is required but not installed. Please install curl."
    exit 1
fi

# Run main function
main "$@"