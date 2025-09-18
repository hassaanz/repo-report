#!/bin/bash

# Git History ASCII Report Generator
# Author: Claude Code Assistant
# Version: 1.0
# Description: Generates comprehensive ASCII formatted git history reports with date range filtering

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
SINCE=""
UNTIL=""
AUTHOR=""
DETAILED=false
OUTPUT_FILE=""
REPO_PATH="."
PRESET=""
FORMAT="ascii"

# Help function
show_help() {
    cat << EOF
Git History ASCII Report Generator

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -s, --since DATE        Start date (e.g., "2025-09-01", "1 week ago", "yesterday")
    -u, --until DATE        End date (e.g., "2025-09-18", "today")
    -p, --preset PERIOD     Quick date range presets (see PRESETS section below)
    -a, --author AUTHOR     Filter by specific author
    -d, --detailed          Show detailed commit breakdown
    -f, --format FORMAT     Output format: ascii, html, markdown (default: ascii)
    -o, --output FILE       Save output to file
    -r, --repo PATH         Repository path (default: current directory)
    -h, --help              Show this help message

EXAMPLES:
    $0                                          # Show all history (ASCII)
    $0 --preset today                           # Today's activity
    $0 --preset last-week --format html         # Last week's activity in HTML
    $0 --preset last-month --detailed --format markdown  # Last month detailed Markdown report
    $0 --since "2025-09-01" --until "2025-09-18" # Specific date range
    $0 --author "John Doe" --format html        # Filter by author in HTML
    $0 --detailed --output report.html --format html     # Detailed HTML report to file
    $0 --preset quarter --format markdown --output quarterly.md  # Quarterly Markdown report

PRESETS:
    today           - Today's commits only
    yesterday       - Yesterday's commits only
    last-week       - Last 7 days (excluding today)
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

DATE FORMATS:
    - Absolute: "2025-09-18", "2025-09-01"
    - Relative: "1 week ago", "2 days ago", "yesterday", "today"
    - ISO format: "2025-09-18T10:30:00"

EOF
}

# Convert preset to date range
apply_preset() {
    local preset="$1"

    case "$preset" in
        "today")
            SINCE="$(date '+%Y-%m-%d 00:00:00')"
            UNTIL="$(date '+%Y-%m-%d 23:59:59')"
            ;;
        "yesterday")
            SINCE="$(date -d 'yesterday' '+%Y-%m-%d 00:00:00' 2>/dev/null || date -v-1d '+%Y-%m-%d 00:00:00')"
            UNTIL="$(date -d 'yesterday' '+%Y-%m-%d 23:59:59' 2>/dev/null || date -v-1d '+%Y-%m-%d 23:59:59')"
            ;;
        "last-week")
            SINCE="7 days ago"
            UNTIL="today"
            ;;
        "this-week")
            # Get Monday of this week
            SINCE="$(date -d 'last monday' '+%Y-%m-%d 00:00:00' 2>/dev/null || date -v-mon '+%Y-%m-%d 00:00:00' 2>/dev/null || echo 'monday')"
            UNTIL="today"
            ;;
        "last-2-weeks"|"sprint")
            SINCE="14 days ago"
            UNTIL="today"
            ;;
        "last-month")
            SINCE="30 days ago"
            UNTIL="today"
            ;;
        "this-month")
            SINCE="$(date '+%Y-%m-01 00:00:00')"
            UNTIL="today"
            ;;
        "last-3-months"|"quarter")
            SINCE="90 days ago"
            UNTIL="today"
            ;;
        "last-6-months")
            SINCE="180 days ago"
            UNTIL="today"
            ;;
        "last-year")
            SINCE="365 days ago"
            UNTIL="today"
            ;;
        "this-year")
            SINCE="$(date '+%Y-01-01 00:00:00')"
            UNTIL="today"
            ;;
        *)
            echo -e "${RED}Error: Unknown preset '$preset'${NC}" >&2
            echo "Available presets: today, yesterday, last-week, this-week, last-2-weeks, last-month, this-month, last-3-months, last-6-months, last-year, this-year, sprint, quarter" >&2
            exit 1
            ;;
    esac

    echo -e "${CYAN}Applied preset '$preset': since='$SINCE', until='$UNTIL'${NC}" >&2
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--since)
                SINCE="$2"
                shift 2
                ;;
            -u|--until)
                UNTIL="$2"
                shift 2
                ;;
            -p|--preset)
                PRESET="$2"
                apply_preset "$PRESET"
                shift 2
                ;;
            -a|--author)
                AUTHOR="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                case "$FORMAT" in
                    ascii|html|markdown)
                        ;;
                    *)
                        echo -e "${RED}Error: Invalid format '$FORMAT'. Supported formats: ascii, html, markdown${NC}" >&2
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -d|--detailed)
                DETAILED=true
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -r|--repo)
                REPO_PATH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Validate repository
validate_repo() {
    if [[ ! -d "$REPO_PATH/.git" ]]; then
        echo -e "${RED}Error: '$REPO_PATH' is not a git repository${NC}" >&2
        exit 1
    fi
}

# Build git log command
build_git_command() {
    local cmd="git -C \"$REPO_PATH\" log --pretty=format:\"%ad|%an|%ae|%s|%H\" --date=short --numstat"

    if [[ -n "$SINCE" ]]; then
        cmd="$cmd --since=\"$SINCE\""
    fi

    if [[ -n "$UNTIL" ]]; then
        cmd="$cmd --until=\"$UNTIL\""
    fi

    if [[ -n "$AUTHOR" ]]; then
        cmd="$cmd --author=\"$AUTHOR\""
    fi

    echo "$cmd"
}

# Process git log data
process_git_data() {
    local git_cmd=$(build_git_command)

    eval "$git_cmd" | awk '
    BEGIN {
        # Initialize arrays
        total_added = 0
        total_removed = 0
        commit_count = 0
    }

    # Process commit headers (pipe-separated)
    /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
        if (NR > 1 && current_date != "") {
            # Store previous commit data
            dates[date_count] = current_date
            authors[date_count] = current_author
            emails[date_count] = current_email
            messages[date_count] = current_message
            hashes[date_count] = current_hash
            added[date_count] = commit_added
            removed[date_count] = commit_removed
            date_count++
        }

        # Parse new commit (split by pipe)
        split($0, commit_fields, "|")
        current_date = commit_fields[1]
        current_author = commit_fields[2]
        current_email = commit_fields[3]
        current_message = commit_fields[4]
        current_hash = commit_fields[5]
        commit_added = 0
        commit_removed = 0
        commit_count++
    }

    # Process file statistics (tab-separated)
    /^[0-9]+\t[0-9]+\t/ {
        # Split by tab to get added, removed, filename
        split($0, stat_fields, "\t")
        if (length(stat_fields) >= 3 && stat_fields[1] ~ /^[0-9]+$/ && stat_fields[2] ~ /^[0-9]+$/) {
            commit_added += stat_fields[1]
            commit_removed += stat_fields[2]
            total_added += stat_fields[1]
            total_removed += stat_fields[2]
        }
    }

    # Process binary files (marked with -)
    /^-\t-\t/ {
        # Binary files - count as 1 addition for tracking
        commit_added += 1
        total_added += 1
    }

    END {
        # Store last commit
        if (current_date != "") {
            dates[date_count] = current_date
            authors[date_count] = current_author
            emails[date_count] = current_email
            messages[date_count] = current_message
            hashes[date_count] = current_hash
            added[date_count] = commit_added
            removed[date_count] = commit_removed
            date_count++
        }

        # Output processed data
        printf "SUMMARY|%d|%d|%d|%d\n", commit_count, total_added, total_removed, date_count

        # Output individual commits
        for (i = 0; i < date_count; i++) {
            printf "COMMIT|%s|%s|%s|%s|%s|%d|%d\n",
                dates[i], authors[i], emails[i], messages[i], hashes[i], added[i], removed[i]
        }

        # Calculate contributor stats
        delete contributor_added
        delete contributor_removed
        delete contributor_commits

        for (i = 0; i < date_count; i++) {
            contributor_added[authors[i]] += added[i]
            contributor_removed[authors[i]] += removed[i]
            contributor_commits[authors[i]]++
        }

        # Output contributor summary
        for (author in contributor_added) {
            printf "CONTRIBUTOR|%s|%d|%d|%d\n",
                author, contributor_commits[author], contributor_added[author], contributor_removed[author]
        }

        # Daily aggregation
        delete daily_added
        delete daily_removed
        delete daily_commits
        delete daily_authors

        for (i = 0; i < date_count; i++) {
            daily_added[dates[i]] += added[i]
            daily_removed[dates[i]] += removed[i]
            daily_commits[dates[i]]++
            if (!(dates[i] SUBSEP authors[i] in daily_authors)) {
                daily_authors[dates[i] SUBSEP authors[i]] = 1
                if (dates[i] in daily_author_count) {
                    daily_author_count[dates[i]]++
                } else {
                    daily_author_count[dates[i]] = 1
                }
            }
        }

        # Output daily summary
        for (date in daily_added) {
            printf "DAILY|%s|%d|%d|%d|%d\n",
                date, daily_commits[date], daily_added[date], daily_removed[date], daily_author_count[date]
        }
    }'
}

# Generate ASCII header
generate_header() {
    local title="$1"
    local width=120

    cat << EOF
╔$(printf '═%.0s' $(seq 1 $((width-2))))╗
║$(printf '%*s' $(((width + ${#title}) / 2)) "$title")$(printf '%*s' $(((width - ${#title}) / 2 - 1)) "")║
╚$(printf '═%.0s' $(seq 1 $((width-2))))╝

EOF
}

# HTML Report Generation Functions
generate_html_report() {
    local data="$1"
    local summary=$(echo "$data" | grep "^SUMMARY|" | head -1)
    local commits=$(echo "$summary" | cut -d'|' -f2)
    local added=$(echo "$summary" | cut -d'|' -f3)
    local removed=$(echo "$summary" | cut -d'|' -f4)
    local net=$((added - removed))

    cat << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Git History Report - $(basename "$REPO_PATH")</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background-color: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; text-align: center; }
        .header h1 { margin: 0; font-size: 2.5em; font-weight: 300; }
        .header p { margin: 10px 0 0; opacity: 0.9; font-size: 1.1em; }
        .content { padding: 30px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: #f8f9fa; border-radius: 8px; padding: 20px; border-left: 4px solid #007bff; }
        .summary-card h3 { margin: 0 0 10px; color: #495057; font-size: 0.9em; text-transform: uppercase; }
        .summary-card .value { font-size: 2em; font-weight: bold; color: #007bff; margin-bottom: 5px; }
        .summary-card .detail { color: #6c757d; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background-color: #f8f9fa; font-weight: 600; color: #495057; }
        tr:hover { background-color: #f8f9fa; }
        .section { margin: 30px 0; }
        .section h2 { color: #495057; border-bottom: 2px solid #007bff; padding-bottom: 10px; margin-bottom: 20px; }
        .activity-indicator { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; font-weight: bold; }
        .activity-peak { background-color: #dc3545; color: white; }
        .activity-high { background-color: #fd7e14; color: white; }
        .activity-moderate { background-color: #ffc107; color: black; }
        .activity-low { background-color: #20c997; color: white; }
        .activity-minimal { background-color: #6f42c1; color: white; }
        .activity-balanced { background-color: #6c757d; color: white; }
        .activity-cleanup { background-color: #17a2b8; color: white; }
        .contributor-card { background: white; border: 1px solid #dee2e6; border-radius: 8px; padding: 20px; margin: 10px 0; }
        .contributor-rank { display: inline-block; width: 30px; height: 30px; border-radius: 50%; background: #007bff; color: white; text-align: center; line-height: 30px; font-weight: bold; margin-right: 10px; }
        .contributor-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 15px; margin-top: 10px; }
        .stat { text-align: center; }
        .stat-value { font-size: 1.2em; font-weight: bold; color: #007bff; }
        .stat-label { font-size: 0.8em; color: #6c757d; text-transform: uppercase; }
        .footer { background-color: #f8f9fa; padding: 20px; border-radius: 0 0 8px 8px; text-align: center; color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Git History Report</h1>
            <p>Repository: $(basename "$REPO_PATH")</p>
EOF

    # Add date range info
    if [[ -n "$SINCE" || -n "$UNTIL" || -n "$PRESET" ]]; then
        echo "            <p>"
        [[ -n "$PRESET" ]] && echo "Preset: $PRESET | "
        [[ -n "$SINCE" ]] && echo "Since: $SINCE | "
        [[ -n "$UNTIL" ]] && echo "Until: $UNTIL"
        echo "            </p>"
    fi

    cat << EOF
        </div>

        <div class="content">
            <div class="summary-grid">
                <div class="summary-card">
                    <h3>Total Commits</h3>
                    <div class="value">$commits</div>
                    <div class="detail">Across all contributors</div>
                </div>
                <div class="summary-card">
                    <h3>Lines Added</h3>
                    <div class="value">$(printf "%'d" $added)</div>
                    <div class="detail">New code additions</div>
                </div>
                <div class="summary-card">
                    <h3>Lines Removed</h3>
                    <div class="value">$(printf "%'d" $removed)</div>
                    <div class="detail">Code deletions</div>
                </div>
                <div class="summary-card">
                    <h3>Net Change</h3>
                    <div class="value $([ $net -ge 0 ] && echo "style=\"color: #28a745;\"" || echo "style=\"color: #dc3545;\"")">${net:+"+"}$(printf "%'d" $net)</div>
                    <div class="detail">Overall code growth</div>
                </div>
            </div>

            <div class="section">
                <h2>📅 Daily Activity</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Commits</th>
                            <th>Lines Added</th>
                            <th>Lines Removed</th>
                            <th>Authors</th>
                            <th>Activity Level</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

    echo "$data" | grep "^DAILY|" | sort -t'|' -k2 | while IFS='|' read -r prefix date commits_day added_day removed_day authors_day; do
        local net_day=$((added_day - removed_day))
        local activity_class="activity-balanced"
        local activity_text="⚖️ Balanced Changes"

        if [[ $net_day -gt 10000 ]]; then
            activity_class="activity-peak"
            activity_text="🔥🔥🔥🔥🔥 Peak Development"
        elif [[ $net_day -gt 5000 ]]; then
            activity_class="activity-high"
            activity_text="🔥🔥🔥🔥 High Activity"
        elif [[ $net_day -gt 1000 ]]; then
            activity_class="activity-moderate"
            activity_text="🔥🔥🔥 Moderate Activity"
        elif [[ $net_day -gt 100 ]]; then
            activity_class="activity-low"
            activity_text="🔥🔥 Low Activity"
        elif [[ $net_day -gt 0 ]]; then
            activity_class="activity-minimal"
            activity_text="🔥 Minimal Activity"
        elif [[ $net_day -lt 0 ]]; then
            activity_class="activity-cleanup"
            activity_text="🧹 Code Cleanup"
        fi

        printf "                        <tr>\n"
        printf "                            <td>%s</td>\n" "$date"
        printf "                            <td>%s</td>\n" "$commits_day"
        printf "                            <td>%s</td>\n" "$(printf "%'d" $added_day)"
        printf "                            <td>%s</td>\n" "$(printf "%'d" $removed_day)"
        printf "                            <td>%s</td>\n" "$authors_day"
        printf "                            <td><span class=\"activity-indicator %s\">%s</span></td>\n" "$activity_class" "$activity_text"
        printf "                        </tr>\n"
    done

    cat << EOF
                    </tbody>
                </table>
            </div>

            <div class="section">
                <h2>👥 Contributors</h2>
EOF

    local rank=1
    echo "$data" | grep "^CONTRIBUTOR|" | sort -t'|' -k4 -nr | while IFS='|' read -r prefix author commits_count added_count removed_count; do
        local net_contrib=$((added_count - removed_count))
        local role_desc="Minor Contributor"

        if [[ $net_contrib -gt 15000 ]]; then
            role_desc="Foundation Builder"
        elif [[ $net_contrib -gt 5000 ]]; then
            role_desc="Lead Developer"
        elif [[ $net_contrib -gt 1000 ]]; then
            role_desc="Feature Contributor"
        elif [[ $net_contrib -gt 100 ]]; then
            role_desc="Regular Contributor"
        fi

        cat << EOF
                <div class="contributor-card">
                    <div style="display: flex; align-items: center; margin-bottom: 15px;">
                        <span class="contributor-rank">$rank</span>
                        <div>
                            <h3 style="margin: 0; color: #495057;">$author</h3>
                            <p style="margin: 5px 0 0; color: #6c757d;">$role_desc</p>
                        </div>
                    </div>
                    <div class="contributor-stats">
                        <div class="stat">
                            <div class="stat-value">$commits_count</div>
                            <div class="stat-label">Commits</div>
                        </div>
                        <div class="stat">
                            <div class="stat-value">$(printf "%'d" $added_count)</div>
                            <div class="stat-label">Added</div>
                        </div>
                        <div class="stat">
                            <div class="stat-value">$(printf "%'d" $removed_count)</div>
                            <div class="stat-label">Removed</div>
                        </div>
                        <div class="stat">
                            <div class="stat-value" style="color: $([ $net_contrib -ge 0 ] && echo "#28a745" || echo "#dc3545")">${net_contrib:+"+"}$(printf "%'d" $net_contrib)</div>
                            <div class="stat-label">Net</div>
                        </div>
                    </div>
                </div>
EOF
        ((rank++))
    done

    if [[ "$DETAILED" == true ]]; then
        cat << EOF
            <div class="section">
                <h2>📋 Detailed Commits</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Author</th>
                            <th>Lines Added</th>
                            <th>Lines Removed</th>
                            <th>Commit Message</th>
                        </tr>
                    </thead>
                    <tbody>
EOF

        echo "$data" | grep "^COMMIT|" | sort -t'|' -k2 | while IFS='|' read -r prefix date author email message hash added_commit removed_commit; do
            printf "                        <tr>\n"
            printf "                            <td>%s</td>\n" "$date"
            printf "                            <td>%s</td>\n" "${author:0:20}"
            printf "                            <td>%s</td>\n" "$(printf "%'d" $added_commit)"
            printf "                            <td>%s</td>\n" "$(printf "%'d" $removed_commit)"
            printf "                            <td>%s</td>\n" "${message:0:80}"
            printf "                        </tr>\n"
        done

        echo "                    </tbody>"
        echo "                </table>"
        echo "            </div>"
    fi

    cat << EOF
        </div>

        <div class="footer">
            Generated on $(date '+%Y-%m-%d %H:%M:%S') by Git History Report Generator v2.0
        </div>
    </div>
</body>
</html>
EOF
}

# Markdown Report Generation Functions
generate_markdown_report() {
    local data="$1"
    local summary=$(echo "$data" | grep "^SUMMARY|" | head -1)
    local commits=$(echo "$summary" | cut -d'|' -f2)
    local added=$(echo "$summary" | cut -d'|' -f3)
    local removed=$(echo "$summary" | cut -d'|' -f4)
    local net=$((added - removed))

    cat << EOF
# 📊 Git History Report

**Repository:** $(basename "$REPO_PATH")
**Generated on:** $(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Add filters info
    if [[ -n "$SINCE" || -n "$UNTIL" || -n "$PRESET" || -n "$AUTHOR" ]]; then
        echo ""
        echo "## 🔍 Filters Applied"
        echo ""
        [[ -n "$PRESET" ]] && echo "- **Preset:** $PRESET"
        [[ -n "$SINCE" ]] && echo "- **Since:** $SINCE"
        [[ -n "$UNTIL" ]] && echo "- **Until:** $UNTIL"
        [[ -n "$AUTHOR" ]] && echo "- **Author:** $AUTHOR"
    fi

    cat << EOF

## 📈 Summary Statistics

| Metric | Value | Description |
|--------|-------|-------------|
| **Total Commits** | $commits | Total number of commits |
| **Lines Added** | $(printf "%'d" $added) | New code additions |
| **Lines Removed** | $(printf "%'d" $removed) | Code deletions |
| **Net Change** | $(printf "%+d" $net) | Overall code growth |

## 📅 Daily Activity Breakdown

| Date | Commits | Added | Removed | Authors | Activity Level |
|------|---------|-------|---------|---------|----------------|
EOF

    echo "$data" | grep "^DAILY|" | sort -t'|' -k2 | while IFS='|' read -r prefix date commits_day added_day removed_day authors_day; do
        local net_day=$((added_day - removed_day))
        local activity_text="⚖️ Balanced"

        if [[ $net_day -gt 10000 ]]; then
            activity_text="🔥🔥🔥🔥🔥 Peak"
        elif [[ $net_day -gt 5000 ]]; then
            activity_text="🔥🔥🔥🔥 High"
        elif [[ $net_day -gt 1000 ]]; then
            activity_text="🔥🔥🔥 Moderate"
        elif [[ $net_day -gt 100 ]]; then
            activity_text="🔥🔥 Low"
        elif [[ $net_day -gt 0 ]]; then
            activity_text="🔥 Minimal"
        elif [[ $net_day -lt 0 ]]; then
            activity_text="🧹 Cleanup"
        fi

        printf "| %s | %s | %s | %s | %s | %s |\n" \
            "$date" "$commits_day" "$(printf "%'d" $added_day)" "$(printf "%'d" $removed_day)" "$authors_day" "$activity_text"
    done

    cat << EOF

## 👥 Contributors

EOF

    local rank=1
    echo "$data" | grep "^CONTRIBUTOR|" | sort -t'|' -k4 -nr | while IFS='|' read -r prefix author commits_count added_count removed_count; do
        local net_contrib=$((added_count - removed_count))
        local role_desc="Minor Contributor"
        local rank_emoji="🏅"

        case $rank in
            1) rank_emoji="🏆" ;;
            2) rank_emoji="🥈" ;;
            3) rank_emoji="🥉" ;;
        esac

        if [[ $net_contrib -gt 15000 ]]; then
            role_desc="Foundation Builder - Project infrastructure and initial setup"
        elif [[ $net_contrib -gt 5000 ]]; then
            role_desc="Lead Developer - Major features and architectural decisions"
        elif [[ $net_contrib -gt 1000 ]]; then
            role_desc="Feature Contributor - Significant feature additions and improvements"
        elif [[ $net_contrib -gt 100 ]]; then
            role_desc="Regular Contributor - Bug fixes and enhancements"
        fi

        cat << EOF
### $rank_emoji $author

- **Commits:** $commits_count
- **Lines Added:** $(printf "%'d" $added_count)
- **Lines Removed:** $(printf "%'d" $removed_count)
- **Net Contribution:** $(printf "%+d" $net_contrib)
- **Role:** $role_desc

EOF
        ((rank++))
    done

    if [[ "$DETAILED" == true ]]; then
        cat << EOF
## 📋 Detailed Commit History

| Date | Author | Added | Removed | Commit Message |
|------|--------|-------|---------|----------------|
EOF

        echo "$data" | grep "^COMMIT|" | sort -t'|' -k2 | while IFS='|' read -r prefix date author email message hash added_commit removed_commit; do
            local truncated_message="${message:0:60}"
            [[ ${#message} -gt 60 ]] && truncated_message="${truncated_message}..."

            printf "| %s | %s | %s | %s | %s |\n" \
                "$date" "${author:0:15}" "$(printf "%'d" $added_commit)" "$(printf "%'d" $removed_commit)" "$truncated_message"
        done

        echo ""
    fi

    cat << EOF
## 🏃‍♂️ Development Velocity

EOF

    local total_days=$(echo "$data" | grep "^DAILY|" | wc -l | tr -d ' ')
    local avg_commits=$(echo "$data" | grep "^DAILY|" | awk -F'|' '{sum+=$3; count++} END {printf "%.1f", sum/count}')

    cat << EOF
- **Total Active Days:** $total_days
- **Average Commits per Day:** $avg_commits
- **Peak Activity Day:** $(echo "$data" | grep "^DAILY|" | sort -t'|' -k4 -nr | head -1 | cut -d'|' -f2)

### Development Pattern Analysis

EOF

    echo "$data" | grep "^DAILY|" | sort -t'|' -k2 | while IFS='|' read -r prefix date commits_day added_day removed_day authors_day; do
        local net_day=$((added_day - removed_day))
        local pattern_desc="Code Cleanup/Refactoring"

        if [[ $net_day -gt 10000 ]]; then
            pattern_desc="Foundation/Major Refactor"
        elif [[ $net_day -gt 5000 ]]; then
            pattern_desc="Feature Development"
        elif [[ $net_day -gt 1000 ]]; then
            pattern_desc="Enhancement Phase"
        elif [[ $net_day -gt 0 ]]; then
            pattern_desc="Maintenance/Bug Fixes"
        fi

        [[ -n "$date" ]] && printf -- "- **%s:** %+d lines - %s\n" "$date" "$net_day" "$pattern_desc"
    done

    echo ""
    echo "---"
    echo ""
    echo "*Report generated by Git History Report Generator v2.0*"
}

# Generate summary table
generate_summary_table() {
    local commits="$1" added="$2" removed="$3" net=$((added - removed))
    local date_range_text=""

    if [[ -n "$SINCE" || -n "$UNTIL" ]]; then
        date_range_text="Date Range: "
        [[ -n "$SINCE" ]] && date_range_text+="from $SINCE "
        [[ -n "$UNTIL" ]] && date_range_text+="to $UNTIL"
    else
        date_range_text="Date Range: All Time"
    fi

    cat << EOF
╔════════════╦══════════════════════╦═════════╦═══════════╦══════════════════════════════════════════════════════════════════════════════════╗
║   METRIC   ║        VALUE         ║  ADDED  ║  REMOVED  ║                                  DETAILS                                         ║
╠════════════╬══════════════════════╬═════════╬═══════════╬══════════════════════════════════════════════════════════════════════════════════╣
║ Commits    ║ $(printf '%20s' "$commits")     ║ $(printf '%7s' "$added")  ║ $(printf '%9s' "$removed")  ║ Net Change: $(printf '%+d' $net) lines$(printf '%*s' $((50 - ${#net} - 17)) "")                            ║
║ Repository ║ $(printf '%-20.20s' "$(basename "$REPO_PATH")")     ║         ║           ║ $(printf '%-80.80s' "$date_range_text")     ║
╚════════════╩══════════════════════╩═════════╩═══════════╩══════════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Generate daily breakdown table
generate_daily_table() {
    local data="$1"

    cat << EOF
╔════════════╦═══════════╦═════════╦═══════════╦═══════════╦════════════════════════════════════════════════════════════════════════════════╗
║    DATE    ║  COMMITS  ║  ADDED  ║  REMOVED  ║ AUTHORS   ║                                 ACTIVITY LEVEL                               ║
╠════════════╬═══════════╬═════════╬═══════════╬═══════════╬════════════════════════════════════════════════════════════════════════════════╣
EOF

    echo "$data" | grep "^DAILY|" | sort -t'|' -k2 | while IFS='|' read -r prefix date commits_day added_day removed_day authors_day; do
        local net=$((added_day - removed_day))
        local activity_level=""

        # Generate activity level visualization
        if [[ $net -gt 10000 ]]; then
            activity_level="🔥🔥🔥🔥🔥 Peak Development"
        elif [[ $net -gt 5000 ]]; then
            activity_level="🔥🔥🔥🔥 High Activity"
        elif [[ $net -gt 1000 ]]; then
            activity_level="🔥🔥🔥 Moderate Activity"
        elif [[ $net -gt 100 ]]; then
            activity_level="🔥🔥 Low Activity"
        elif [[ $net -gt 0 ]]; then
            activity_level="🔥 Minimal Activity"
        elif [[ $net -eq 0 ]]; then
            activity_level="⚖️ Balanced Changes"
        else
            activity_level="🧹 Code Cleanup"
        fi

        printf "║ %-10s ║ %9s ║ %7s ║ %9s ║ %9s ║ %-78s ║\n" \
            "$date" "$commits_day" "$added_day" "$removed_day" "$authors_day" "$activity_level"
    done

    cat << EOF
╚════════════╩═══════════╩═════════╩═══════════╩═══════════╩════════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Generate contributor breakdown
generate_contributor_table() {
    local data="$1"

    cat << EOF
╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                   👥 CONTRIBUTOR BREAKDOWN                                                                           ║
╠═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                                                                       ║
EOF

    local rank=1
    local rank_emojis=("🏆" "🥈" "🥉" "🎖️" "🎗️")

    echo "$data" | grep "^CONTRIBUTOR|" | sort -t'|' -k4 -nr | while IFS='|' read -r prefix author commits_count added_count removed_count; do
        local net=$((added_count - removed_count))
        local emoji="${rank_emojis[$((rank-1))]:-📝}"

        printf "║  %s %-20s                                                                                                                  ║\n" \
            "$emoji" "$author"
        printf "║     • Commits: %-8s • Lines Added: %-8s • Lines Removed: %-8s • Net: %+d%-30s ║\n" \
            "$commits_count" "$added_count" "$removed_count" "$net" ""

        # Add role description based on contribution level
        if [[ $net -gt 15000 ]]; then
            printf "║     • Role: Foundation Builder - Project infrastructure and initial setup%-50s ║\n" ""
        elif [[ $net -gt 5000 ]]; then
            printf "║     • Role: Lead Developer - Major features and architectural decisions%-48s ║\n" ""
        elif [[ $net -gt 1000 ]]; then
            printf "║     • Role: Feature Contributor - Significant feature additions and improvements%-41s ║\n" ""
        elif [[ $net -gt 100 ]]; then
            printf "║     • Role: Regular Contributor - Bug fixes and small enhancements%-50s ║\n" ""
        else
            printf "║     • Role: Minor Contributor - Documentation and small fixes%-54s ║\n" ""
        fi

        printf "║                                                                                                                                       ║\n"
        ((rank++))
    done

    cat << EOF
╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Generate detailed commit table
generate_detailed_table() {
    local data="$1"

    cat << EOF
╔════════════╦══════════════════════╦═════════╦═══════════╦═══════════════════════════════════════════════════════════════════════════════╗
║    DATE    ║    CONTRIBUTOR       ║  ADDED  ║  REMOVED  ║                                COMMIT MESSAGE                                ║
╠════════════╬══════════════════════╬═════════╬═══════════╬═══════════════════════════════════════════════════════════════════════════════╣
EOF

    echo "$data" | grep "^COMMIT|" | sort -t'|' -k2 | while IFS='|' read -r prefix date author email message hash added_commit removed_commit; do
        # Truncate long messages
        local truncated_message="$message"
        if [[ ${#message} -gt 75 ]]; then
            truncated_message="${message:0:72}..."
        fi

        # Truncate long author names
        local truncated_author="$author"
        if [[ ${#author} -gt 18 ]]; then
            truncated_author="${author:0:15}..."
        fi

        printf "║ %-10s ║ %-20s ║ %7s ║ %9s ║ %-77s ║\n" \
            "$date" "$truncated_author" "$added_commit" "$removed_commit" "$truncated_message"
    done

    cat << EOF
╚════════════╩══════════════════════╩═════════╩═══════════╩═══════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Generate velocity metrics
generate_velocity_metrics() {
    local data="$1"
    local total_days=$(echo "$data" | grep "^DAILY|" | wc -l)

    cat << EOF
╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                     🏃‍♂️ VELOCITY METRICS                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                                                                       ║
║  📊 Development Statistics:                                                                                                                           ║
║     • Total Active Days: $total_days                                                                                                                          ║
║     • Average Commits/Day: $(echo "$data" | grep "^DAILY|" | awk -F'|' '{sum+=$3; count++} END {printf "%.1f", sum/count}')                                                                                                                ║
║     • Peak Activity Day: $(echo "$data" | grep "^DAILY|" | sort -t'|' -k4 -nr | head -1 | cut -d'|' -f2)                                                                                                               ║
║                                                                                                                                                       ║
║  🚀 Development Pattern Analysis:                                                                                                                     ║
EOF

    echo "$data" | grep "^DAILY|" | sort -t'|' -k2 | while IFS='|' read -r prefix date commits_day added_day removed_day authors_day; do
        local net=$((added_day - removed_day))
        local activity_desc=""

        if [[ $net -gt 10000 ]]; then
            activity_desc="Foundation/Major Refactor"
        elif [[ $net -gt 5000 ]]; then
            activity_desc="Feature Development"
        elif [[ $net -gt 1000 ]]; then
            activity_desc="Enhancement Phase"
        elif [[ $net -gt 0 ]]; then
            activity_desc="Maintenance/Bug Fixes"
        else
            activity_desc="Code Cleanup/Refactoring"
        fi

        printf "║     • %s: %+d lines - %s%-30s ║\n" "$date" "$net" "$activity_desc" ""
    done

    cat << EOF
║                                                                                                                                                       ║
╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

EOF
}

# Main report generation
generate_report() {
    echo -e "${BLUE}Processing git history...${NC}" >&2

    local data=$(process_git_data)
    local summary=$(echo "$data" | grep "^SUMMARY|" | head -1)

    if [[ -z "$summary" ]]; then
        echo -e "${RED}No commits found in the specified range${NC}" >&2
        exit 1
    fi

    # Generate report based on format
    case "$FORMAT" in
        html)
            generate_html_report "$data"
            ;;
        markdown)
            generate_markdown_report "$data"
            ;;
        ascii|*)
            local commits=$(echo "$summary" | cut -d'|' -f2)
            local added=$(echo "$summary" | cut -d'|' -f3)
            local removed=$(echo "$summary" | cut -d'|' -f4)

            # Generate ASCII report sections
            generate_header "📊 GIT REPOSITORY HISTORY REPORT"
            generate_summary_table "$commits" "$added" "$removed"
            generate_daily_table "$data"
            generate_contributor_table "$data"

            if [[ "$DETAILED" == true ]]; then
                generate_detailed_table "$data"
            fi

            generate_velocity_metrics "$data"

            # Footer
            cat << EOF
╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                          Generated on $(date '+%Y-%m-%d %H:%M:%S') by Git History Report Generator                                          ║
╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
EOF
            ;;
    esac
}

# Main execution
main() {
    parse_args "$@"
    validate_repo

    echo -e "${GREEN}Git History ASCII Report Generator${NC}" >&2
    echo -e "${YELLOW}Repository: $REPO_PATH${NC}" >&2

    if [[ -n "$SINCE" ]]; then
        echo -e "${YELLOW}Since: $SINCE${NC}" >&2
    fi

    if [[ -n "$UNTIL" ]]; then
        echo -e "${YELLOW}Until: $UNTIL${NC}" >&2
    fi

    if [[ -n "$AUTHOR" ]]; then
        echo -e "${YELLOW}Author: $AUTHOR${NC}" >&2
    fi

    if [[ -n "$PRESET" ]]; then
        echo -e "${YELLOW}Preset: $PRESET${NC}" >&2
    fi

    echo "" >&2

    if [[ -n "$OUTPUT_FILE" ]]; then
        generate_report > "$OUTPUT_FILE"
        echo -e "${GREEN}Report saved to: $OUTPUT_FILE${NC}" >&2
    else
        generate_report
    fi
}

# Run main function with all arguments
main "$@"