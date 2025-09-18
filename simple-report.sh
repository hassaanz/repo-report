#!/bin/bash

# Simplified Git History Reporter - No Verbose Flags
# Test version to isolate verbose flag issues

set -euo pipefail

# Configuration
GITHUB_USER="hassaanz"
GITHUB_REPO="repo-report"
GITHUB_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Default server URL
SERVER_URL=${GIT_REPORT_SERVER_URL:-"http://localhost:3001"}

# Default report options
PRESET="last-week"
FORMAT="html"
TTL=3600

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Simple logging functions (always show output)
log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_step() {
    echo -e "${PURPLE}🔄 $1${NC}" >&2
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository. Please run this from within a git repository."
        exit 1
    fi

    # Check required commands
    local missing_deps=()
    for cmd in curl jq; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Create temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d -t git-history-reporter.XXXXXX)
    echo "Created temp dir: $TEMP_DIR" >&2

    # Cleanup function
    cleanup_temp_dir() {
        if [[ -d "$TEMP_DIR" ]]; then
            echo "Cleaning up: $TEMP_DIR" >&2
            rm -rf "$TEMP_DIR"
        fi
    }

    # Register cleanup function
    trap cleanup_temp_dir EXIT
}

# Download script from GitHub
download_script() {
    local script_path="$1"
    local local_filename="$2"
    local url="$BASE_URL/$script_path"

    echo "Downloading $script_path..." >&2

    if ! curl -fsSL "$url" -o "$TEMP_DIR/$local_filename"; then
        log_error "Failed to download $script_path from $url"
        exit 1
    fi

    chmod +x "$TEMP_DIR/$local_filename"
    echo "Downloaded: $local_filename" >&2
}

# Download all required scripts
download_scripts() {
    log_step "Downloading scripts from GitHub..."

    download_script "bash/git-history-report.sh" "git-history-report.sh"
    download_script "scripts/upload-report.sh" "upload-report.sh"

    log_success "All scripts downloaded successfully"
}

# Generate and upload report
generate_and_upload_report() {
    log_step "Generating git history report..."

    # Build commands
    local report_cmd="$TEMP_DIR/git-history-report.sh --preset \"$PRESET\" --format \"$FORMAT\" --repo ."
    local upload_cmd="$TEMP_DIR/upload-report.sh --server \"$SERVER_URL\" --verbose"

    echo "Report command: $report_cmd" >&2
    echo "Upload command: $upload_cmd" >&2

    # Generate report and pipe to upload script
    # Capture first line which should be the URL
    if REPORT_URL=$(eval "$report_cmd" | eval "$upload_cmd" | head -1); then
        log_success "Report generated and uploaded successfully!"

        echo ""
        log_success "🎉 Your git history report is ready!"
        echo ""
        echo -e "${CYAN}📊 Report URL: $REPORT_URL${NC}"
        echo ""
        log_success "💡 Tip: Bookmark this URL to share with your team"
        echo ""

        # Output the URL as the final line (main result for scripts)
        echo "$REPORT_URL"
    else
        log_error "Failed to generate or upload report"
        exit 1
    fi
}

# Main execution
main() {
    # Show banner
    echo -e "${CYAN}📊 Simple Git History Reporter${NC}"
    echo -e "${BLUE}Fetching scripts from GitHub and generating report...${NC}"
    echo ""

    check_prerequisites
    setup_temp_dir
    download_scripts
    generate_and_upload_report
}

# Handle interrupts gracefully
trap 'log_error "Operation interrupted"; exit 130' INT TERM

# Run main function
main "$@"