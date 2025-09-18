#!/bin/bash

# Git History Report Generator and Uploader
# Generates git history reports and uploads them to the server
# Usage: ./generate-and-upload.sh --preset last-week
#        ./generate-and-upload.sh --since "2025-09-01" --until "2025-09-15" --author "john@company.com"

set -euo pipefail

# Default configuration
DEFAULT_PRESET="last-week"
DEFAULT_FORMAT="html"
DEFAULT_TTL=3600
REPO_PATH="."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_SCRIPT_PATH="${SCRIPT_DIR}/../bash/git-history-report.sh"
UPLOAD_SCRIPT_PATH="${SCRIPT_DIR}/upload-report.sh"

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
Git History Report Generator and Uploader

Generates git history reports using git-history-report.sh and uploads them to the server.

USAGE:
    $0 [REPORT_OPTIONS] [UPLOAD_OPTIONS]

REPORT OPTIONS:
    -p, --preset PERIOD     Quick date range presets (default: last-week)
    -s, --since DATE        Start date (e.g., "2025-09-01", "1 week ago")
    -u, --until DATE        End date (e.g., "2025-09-18", "today")
    -a, --author AUTHOR     Filter by specific author
    -f, --format FORMAT     Output format: html, markdown, ascii (default: html)
    -d, --detailed          Show detailed commit breakdown
    -r, --repo PATH         Repository path (default: current directory)

UPLOAD OPTIONS:
    -t, --ttl SECONDS       Time to live in seconds (default: 3600, max: 86400)
    --server URL            Server URL (default: \$GIT_REPORT_SERVER_URL or http://localhost:3001)
    -v, --verbose           Show detailed output
    -q, --quiet             Suppress all output except the final URL

GENERAL OPTIONS:
    -h, --help              Show this help message
    --dry-run               Generate report but don't upload (save to file instead)
    --save-local FILE       Save report locally in addition to uploading

PRESETS:
    today           - Today's commits only
    yesterday       - Yesterday's commits only
    last-week       - Last 7 days (default)
    this-week       - This week (Monday to today)
    last-2-weeks    - Last 14 days
    last-month      - Last 30 days
    this-month      - This month (1st to today)
    last-3-months   - Last 90 days
    last-6-months   - Last 180 days
    last-year       - Last 365 days
    this-year       - This year (January 1st to today)
    sprint          - Last 14 days (common sprint length)
    quarter         - Last 90 days (quarterly review)

EXAMPLES:
    # Generate and upload weekly report
    $0 --preset last-week

    # Detailed monthly report with custom TTL
    $0 --preset last-month --detailed --ttl 7200

    # Specific author and date range
    $0 --author "john.doe@company.com" --since "2025-09-01" --until "2025-09-15"

    # Generate report but save locally instead of uploading
    $0 --preset today --dry-run --save-local today-report.html

    # Quiet mode (only output the final URL)
    $0 --preset last-week --quiet

    # Custom repository path
    $0 --repo /path/to/other/repo --preset quarter --verbose

ENVIRONMENT VARIABLES:
    GIT_REPORT_SERVER_URL   Default server URL

EXIT CODES:
    0   Success
    1   Invalid arguments or usage
    2   Git report generation failed
    3   Upload failed
    4   Missing dependencies

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

log_step() {
    [ "$QUIET" != "true" ] && echo -e "${PURPLE}🔄 $1${NC}" >&2
}

# Initialize variables
init_vars() {
    PRESET=""
    SINCE=""
    UNTIL=""
    AUTHOR=""
    FORMAT="$DEFAULT_FORMAT"
    DETAILED=false
    TTL="$DEFAULT_TTL"
    SERVER_URL=""
    VERBOSE=false
    QUIET=false
    DRY_RUN=false
    SAVE_LOCAL=""
}

# Parse command line arguments
parse_args() {
    init_vars

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
            -r|--repo)
                REPO_PATH="$2"
                shift 2
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --save-local)
                SAVE_LOCAL="$2"
                shift 2
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

    # Set default preset if none specified and no date range given
    if [[ -z "$PRESET" && -z "$SINCE" && -z "$UNTIL" ]]; then
        PRESET="$DEFAULT_PRESET"
        log_info "No preset or date range specified, using default: $PRESET"
    fi
}

# Validate dependencies and paths
validate_dependencies() {
    log_step "Validating dependencies..."

    # Check git report script
    if [[ ! -f "$GIT_SCRIPT_PATH" ]]; then
        log_error "Git history report script not found at: $GIT_SCRIPT_PATH"
        exit 4
    fi

    if [[ ! -x "$GIT_SCRIPT_PATH" ]]; then
        log_warning "Git history report script is not executable, fixing..."
        chmod +x "$GIT_SCRIPT_PATH" || {
            log_error "Failed to make git script executable"
            exit 4
        }
    fi

    # Check upload script (only if not dry run)
    if [[ "$DRY_RUN" = "false" ]]; then
        if [[ ! -f "$UPLOAD_SCRIPT_PATH" ]]; then
            log_error "Upload script not found at: $UPLOAD_SCRIPT_PATH"
            exit 4
        fi

        if [[ ! -x "$UPLOAD_SCRIPT_PATH" ]]; then
            log_warning "Upload script is not executable, fixing..."
            chmod +x "$UPLOAD_SCRIPT_PATH" || {
                log_error "Failed to make upload script executable"
                exit 4
            }
        fi
    fi

    # Check repository path
    if [[ ! -d "$REPO_PATH" ]]; then
        log_error "Repository path does not exist: $REPO_PATH"
        exit 1
    fi

    if [[ ! -d "$REPO_PATH/.git" ]]; then
        log_error "Path is not a git repository: $REPO_PATH"
        exit 1
    fi

    log_info "All dependencies validated"
}

# Build git report command
build_git_command() {
    local cmd="\"$GIT_SCRIPT_PATH\""

    [[ -n "$PRESET" ]] && cmd="$cmd --preset \"$PRESET\""
    [[ -n "$SINCE" ]] && cmd="$cmd --since \"$SINCE\""
    [[ -n "$UNTIL" ]] && cmd="$cmd --until \"$UNTIL\""
    [[ -n "$AUTHOR" ]] && cmd="$cmd --author \"$AUTHOR\""
    [[ "$DETAILED" = "true" ]] && cmd="$cmd --detailed"
    cmd="$cmd --format \"$FORMAT\""
    cmd="$cmd --repo \"$REPO_PATH\""

    echo "$cmd"
}

# Generate the report
generate_report() {
    log_step "Generating git history report..."

    local git_cmd=$(build_git_command)
    log_info "Command: $git_cmd"
    # Execute git report generation
    if ! REPORT_CONTENT=$(eval "$git_cmd" 2>/dev/null); then
        log_error "Failed to generate git history report"
        log_error "Check that the repository path is correct and contains commits"
        exit 2
    fi

    # Validate generated content
    if [[ -z "$REPORT_CONTENT" ]]; then
        log_error "Git report script produced empty output"
        exit 2
    fi

    local content_size=$(echo -n "$REPORT_CONTENT" | wc -c | tr -d ' ')
    log_success "Report generated successfully ($content_size bytes)"

    # Show content preview in verbose mode
    if [[ "$VERBOSE" = "true" ]]; then
        log_info "Content preview:"
        echo "$REPORT_CONTENT" | head -5 | sed 's/^/  /' >&2
        echo "  ..." >&2
        echo "$REPORT_CONTENT" | tail -2 | sed 's/^/  /' >&2
    fi
}

# Save report locally
save_local_report() {
    local filename="$1"

    log_step "Saving report to: $filename"

    echo "$REPORT_CONTENT" > "$filename"

    if [[ -f "$filename" ]]; then
        local file_size=$(wc -c < "$filename" | tr -d ' ')
        log_success "Report saved locally ($file_size bytes)"
    else
        log_error "Failed to save report to: $filename"
        exit 2
    fi
}

# Upload the report
upload_report() {
    log_step "Uploading report to server..."

    local upload_cmd="\"$UPLOAD_SCRIPT_PATH\""

    [[ -n "$SERVER_URL" ]] && upload_cmd="$upload_cmd --server \"$SERVER_URL\""
    [[ "$TTL" != "$DEFAULT_TTL" ]] && upload_cmd="$upload_cmd --ttl \"$TTL\""
    if [[ "$VERBOSE" = "true" ]]; then
        upload_cmd="$upload_cmd --verbose"
    elif [[ "$QUIET" = "true" ]]; then
        upload_cmd="$upload_cmd --quiet"
    fi
    # Normal mode: don't add any verbosity flags, let upload script use defaults

    log_info "Upload command: $upload_cmd"

    # Pipe report content to upload script
    if REPORT_URL=$(echo "$REPORT_CONTENT" | eval "$upload_cmd"); then
        log_success "Report uploaded successfully!"

        # Output the URL (main result)
        echo "$REPORT_URL"
    else
        log_error "Failed to upload report"
        exit 3
    fi
}

# Main execution
main() {
    parse_args "$@"
    validate_dependencies
    generate_report

    # Save locally if requested
    if [[ -n "$SAVE_LOCAL" ]]; then
        save_local_report "$SAVE_LOCAL"
    fi

    # Handle dry run
    if [[ "$DRY_RUN" = "true" ]]; then
        if [[ -z "$SAVE_LOCAL" ]]; then
            # No local save specified, create default filename
            local timestamp=$(date '+%Y%m%d-%H%M%S')
            local default_file="git-report-${timestamp}.${FORMAT}"
            save_local_report "$default_file"
        fi
        log_success "Dry run completed. Report not uploaded."
        return 0
    fi

    # Upload report
    upload_report
}

# Handle interrupts gracefully
trap 'log_error "Operation interrupted"; exit 130' INT TERM

# Run main function
main "$@"