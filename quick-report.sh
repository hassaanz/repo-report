#!/bin/bash

# Git History Reporter - One-Command Installer & Report Generator
# Fetches scripts from GitHub and generates a report instantly
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash -s -- --preset last-week --server https://reports.company.com
#
# This script will:
# 1. Download the git-history-report.sh and upload scripts from GitHub
# 2. Generate a git history report for the current repository
# 3. Upload it to a server and return a shareable URL
# 4. Clean up temporary files

set -euo pipefail

# Configuration
GITHUB_USER=${GITHUB_USER:-"hassaanz"}
GITHUB_REPO=${GITHUB_REPO:-"repo-report"}
GITHUB_BRANCH=${GITHUB_BRANCH:-"main"}
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Default server URL (can be overridden)
DEFAULT_SERVER_URL="http://localhost:3001"
SERVER_URL=${GIT_REPORT_SERVER_URL:-$DEFAULT_SERVER_URL}

# Default report options
DEFAULT_PRESET="last-week"
DEFAULT_FORMAT="html"
DEFAULT_TTL=3600

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << EOF
Git History Reporter - One-Command Installer & Report Generator

Downloads scripts from GitHub and generates a git history report instantly.

USAGE:
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash -s -- [OPTIONS]

OPTIONS:
    -p, --preset PERIOD     Quick date range presets (default: last-week)
    -s, --since DATE        Start date (e.g., "2025-09-01", "1 week ago")
    -u, --until DATE        End date (e.g., "2025-09-18", "today")
    -a, --author AUTHOR     Filter by specific author
    -d, --detailed          Show detailed commit breakdown
    -f, --format FORMAT     Output format: html, markdown, ascii (default: html)
    -t, --ttl SECONDS       Time to live in seconds (default: 3600, max: 86400)
    --server URL            Server URL (default: \$GIT_REPORT_SERVER_URL or http://localhost:3001)
    -v, --verbose           Show detailed output
    -q, --quiet             Suppress all output except the final URL
    -h, --help              Show this help message
    --keep-scripts          Don't delete downloaded scripts after use

EXAMPLES:
    # Basic usage - generate last week's report
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash

    # Custom preset with verbose output
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash -s -- --preset last-month --verbose

    # Specific author and date range
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash -s -- \\
      --since "2025-09-01" --until "2025-09-15" --author "john@company.com" --detailed

    # Custom server and TTL
    curl -fsSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/quick-report.sh | bash -s -- \\
      --preset today --server https://my-reports.company.com --ttl 7200

PRESETS:
    today, yesterday, last-week, this-week, last-2-weeks, last-month,
    this-month, last-3-months, quarter, last-6-months, last-year,
    this-year, sprint

ENVIRONMENT VARIABLES:
    GIT_REPORT_SERVER_URL   Default server URL
    GITHUB_USER             GitHub username (default: USER)
    GITHUB_REPO             GitHub repository name (default: REPO)
    GITHUB_BRANCH           GitHub branch (default: main)

EOF
}

# Logging functions - simplified to avoid flag issues
log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_success() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${GREEN}✅ $1${NC}" >&2
    fi
}

log_info() {
    if [[ "${VERBOSE:-false}" = "true" ]]; then
        echo -e "${BLUE}ℹ️  $*${NC}" >&2
    fi
}

log_warning() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${YELLOW}⚠️  $1${NC}" >&2
    fi
}

log_step() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${PURPLE}🔄 $1${NC}" >&2
    fi
}


# Initialize variables
init_vars() {
    PRESET="$DEFAULT_PRESET"
    SINCE=""
    UNTIL=""
    AUTHOR=""
    FORMAT="$DEFAULT_FORMAT"
    DETAILED=false
    TTL="$DEFAULT_TTL"
    VERBOSE=false
    QUIET=false
    KEEP_SCRIPTS=false
    TEMP_DIR=""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--preset)
                PRESET="$2"
                shift 2
                ;;
            -s|--since)
                SINCE="$2"
                shift 2
                ;;
            -u|--until)
                UNTIL="$2"
                shift 2
                ;;
            -a|--author)
                AUTHOR="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                if [[ ! "$FORMAT" =~ ^(html|markdown|ascii)$ ]]; then
                    log_error "Invalid format: $FORMAT. Must be html, markdown, or ascii"
                    exit 1
                fi
                shift 2
                ;;
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -t|--ttl)
                TTL="$2"
                if ! [[ "$TTL" =~ ^[0-9]+$ ]] || [ "$TTL" -le 0 ] || [ "$TTL" -gt 86400 ]; then
                    log_error "Invalid TTL: $TTL. Must be a positive integer ≤ 86400 (24 hours)"
                    exit 1
                fi
                shift 2
                ;;
            --server)
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
            --keep-scripts)
                KEEP_SCRIPTS=true
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
        log_error "Please install the missing dependencies:"
        log_error "  macOS: brew install ${missing_deps[*]}"
        log_error "  Ubuntu/Debian: apt-get install ${missing_deps[*]}"
        log_error "  CentOS/RHEL: yum install ${missing_deps[*]}"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

# Create temporary directory
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d -t git-history-reporter.XXXXXX)
    log_info "Created temporary directory: $TEMP_DIR"

    # Cleanup function
    cleanup_temp_dir() {
        if [[ "$KEEP_SCRIPTS" = "false" ]] && [[ -d "$TEMP_DIR" ]]; then
            log_info "Cleaning up temporary directory: $TEMP_DIR"
            rm -rf "$TEMP_DIR"
        elif [[ "$KEEP_SCRIPTS" = "true" ]]; then
            log_info "Scripts kept in: $TEMP_DIR"
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

    log_info "Downloading $script_path..."

    if ! curl -fsSL "$url" -o "$TEMP_DIR/$local_filename"; then
        log_error "Failed to download $script_path from $url"
        log_error "Please check:"
        log_error "  1. GitHub repository URL is correct"
        log_error "  2. Branch name is correct (current: $GITHUB_BRANCH)"
        log_error "  3. File exists in the repository"
        log_error "  4. Internet connection is working"
        exit 1
    fi

    chmod +x "$TEMP_DIR/$local_filename"
    log_info "Downloaded and made executable: $local_filename"
}

# Download all required scripts
download_scripts() {
    log_step "Downloading scripts from GitHub..."

    download_script "bash/git-history-report.sh" "git-history-report.sh"
    download_script "scripts/upload-report.sh" "upload-report.sh"

    log_success "All scripts downloaded successfully"
}

# Build git report command
build_report_command() {
    local cmd="$TEMP_DIR/git-history-report.sh"

    [[ -n "$PRESET" ]] && cmd="$cmd --preset \"$PRESET\""
    [[ -n "$SINCE" ]] && cmd="$cmd --since \"$SINCE\""
    [[ -n "$UNTIL" ]] && cmd="$cmd --until \"$UNTIL\""
    [[ -n "$AUTHOR" ]] && cmd="$cmd --author \"$AUTHOR\""
    [[ "$DETAILED" = "true" ]] && cmd="$cmd --detailed"
    cmd="$cmd --format \"$FORMAT\""
    cmd="$cmd --repo ."

    echo "$cmd"
}

# Build upload command
build_upload_command() {
    local cmd="$TEMP_DIR/upload-report.sh"

    cmd="$cmd --server \"$SERVER_URL\""
    [[ "$TTL" != "$DEFAULT_TTL" ]] && cmd="$cmd --ttl \"$TTL\""

    # Always use verbose mode for upload script but we'll control display
    cmd="$cmd --verbose"

    echo "$cmd"
}

# Generate and upload report
generate_and_upload_report() {
    log_step "Generating git history report..."

    local report_cmd=$(build_report_command)
    local upload_cmd=$(build_upload_command)

    log_info "Report command: $report_cmd"
    log_info "Upload command: $upload_cmd"

    # Generate report and pipe to upload script
    # Only redirect stderr in quiet mode to suppress upload script logs
    if [[ "$QUIET" = "true" ]]; then
        REPORT_URL=$(eval "$report_cmd" | eval "$upload_cmd" 2>/dev/null | head -1)
    else
        REPORT_URL=$(eval "$report_cmd" | eval "$upload_cmd" | head -1)
    fi

    if [[ -n "$REPORT_URL" ]]; then
        log_success "Report generated and uploaded successfully!"

        # Extract report hash for badge URL
        REPORT_HASH=$(echo "$REPORT_URL" | sed 's/.*\/r\///')
        BADGE_URL="${REPORT_URL%/r/*}/api/reports/$REPORT_HASH/badge"

        if [[ "$QUIET" != "true" ]]; then
            echo ""
            log_success "🎉 Your git history report is ready!"
            echo ""
            echo -e "${CYAN}📊 Report URL: $REPORT_URL${NC}"
            echo -e "${CYAN}🏷️  Badge URL: $BADGE_URL${NC}"
            echo ""
            log_success "💡 Tip: Use the badge URL in your GitHub README!"
            echo -e "${BLUE}ℹ️  Markdown: ![Git Activity]($BADGE_URL)${NC}"
            log_success "⏰ Both URLs will expire automatically for security"
            echo ""
        fi

        # Output the URL as the final line (main result for scripts)
        echo "$REPORT_URL"
    else
        log_error "Failed to generate or upload report"
        exit 1
    fi
}

# Show configuration
show_config() {
    log_info "Configuration:"
    log_info "  GitHub: $GITHUB_USER/$GITHUB_REPO ($GITHUB_BRANCH)"
    log_info "  Server: $SERVER_URL"
    log_info "  Preset: $PRESET"
    [[ -n "$SINCE" ]] && log_info "  Since: $SINCE"
    [[ -n "$UNTIL" ]] && log_info "  Until: $UNTIL"
    [[ -n "$AUTHOR" ]] && log_info "  Author: $AUTHOR"
    log_info "  Format: $FORMAT"
    log_info "  Detailed: $DETAILED"
    log_info "  TTL: $TTL seconds"
}

# Main execution
main() {
    # Initialize variables first
    init_vars

    # Parse arguments early to set QUIET flag
    parse_args "$@"

    # Show banner
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${CYAN}📊 Git History Reporter - One-Command Generator${NC}"
        echo -e "${BLUE}Fetching scripts from GitHub and generating report...${NC}"
        echo ""
    fi

    show_config
    check_prerequisites
    setup_temp_dir
    download_scripts
    generate_and_upload_report
}

# Handle interrupts gracefully
trap 'log_error "Operation interrupted"; exit 130' INT TERM

# Run main function
main "$@"