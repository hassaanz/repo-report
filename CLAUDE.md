# Git History Reporter - Claude Configuration

## Project Overview

A comprehensive system for generating, serving, and sharing beautiful git repository history reports. The project consists of three main components that work together to provide a complete solution for git analytics and report sharing.

## Quick Development Setup

```bash
# 1. Start the server
cd server
bun install
bun run dev

# 2. Test report generation (in another terminal)
./bash/git-history-report.sh --preset today --format html

# 3. Test full integration pipeline
export GIT_REPORT_SERVER_URL=http://localhost:3001
./scripts/generate-and-upload.sh --preset last-week --verbose

# 4. Run comprehensive tests
cd server
bun run test:functionality
```

## Development Commands by Component

### 🏗️ Core System Commands

```bash
# Initialize development environment
git clone <repository>
cd gitHistoryReporter

# Test bash script functionality
./bash/git-history-report.sh --help
./bash/git-history-report.sh --preset today --format html > test.html

# Test integration scripts
export GIT_REPORT_SERVER_URL=http://localhost:3001
echo "<html>test content</html>" | ./scripts/upload-report.sh --verbose
./scripts/generate-and-upload.sh --preset today --dry-run
```

### 🌐 Server Development Commands

```bash
cd server/

# Development workflow
bun install                    # Install dependencies
bun run dev                   # Start development server with hot reload
bun run build                 # Build for production
bun run start                 # Start production server

# Testing and validation
bun run test                  # Run unit tests
bun run test:functionality    # End-to-end functionality test
bun run typecheck            # TypeScript validation
bun run lint                 # Code linting

# Debugging
curl http://localhost:3001/health                    # Health check
curl http://localhost:3001/api/reports/health        # Service stats
```

### 📊 Report Generation Commands

```bash
# Basic report generation
./bash/git-history-report.sh --preset last-week --format html
./bash/git-history-report.sh --since "2025-09-01" --detailed --format html

# Integration with server
./scripts/generate-and-upload.sh --preset last-month --verbose
./scripts/generate-and-upload.sh --author "john@company.com" --detailed --ttl 7200

# Testing and dry-runs
./scripts/generate-and-upload.sh --preset today --dry-run --save-local test.html
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Git Repository                       │
│  (Source of truth for code history and analytics)      │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│               bash/git-history-report.sh                │
│  • Analyzes git history and generates reports          │
│  • Multiple formats: HTML, Markdown, ASCII             │
│  • Rich visualizations and analytics                   │
│  • Preset date ranges and custom filtering             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│              scripts/upload-report.sh                  │
│  • Accepts HTML content via stdin                      │
│  • Uploads to server API                               │
│  • Returns shareable URLs with expiration              │
│  • Comprehensive error handling                        │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  Server (Bun + Fastify)                │
│  • REST API for report storage                         │
│  • Hash-based filename generation                      │
│  • Short-lived URL generation                          │
│  • Beautiful web interface                             │
│  • Automatic cleanup and expiration                    │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│                  Shareable Reports                     │
│  • Public URLs: /r/{hash}                              │
│  • Automatic expiration                                │
│  • Beautiful HTML visualizations                       │
│  • Team sharing and collaboration                      │
└─────────────────────────────────────────────────────────┘
```

## Key Features & Capabilities

### 📈 Report Generation (bash/git-history-report.sh)
- **Multiple Output Formats**: HTML (interactive), Markdown (portable), ASCII (terminal-friendly)
- **Rich Analytics**: Contributor analysis, development velocity, activity patterns
- **Visual Indicators**: 🔥🔥🔥🔥🔥 activity levels, 🏆 contributor rankings
- **Flexible Filtering**: 12 preset date ranges, custom dates, author filtering
- **Detailed Breakdowns**: Commit-level analysis, file statistics

### 🌐 Web Server (server/)
- **Modern Stack**: Bun runtime, Fastify framework, TypeScript
- **Beautiful UI**: Interactive documentation with tabbed interface
- **RESTful API**: Complete endpoints for report management
- **Security**: Hash-based URLs, automatic expiration, input validation
- **Monitoring**: Health checks, service statistics, error tracking

### 🔧 Integration Scripts (scripts/)
- **upload-report.sh**: Pipe-friendly HTML uploader with comprehensive options
- **generate-and-upload.sh**: One-command solution for generation and sharing
- **Production Ready**: Error handling, logging, environment variable support
- **Testing Support**: Dry-run mode, verbose output, custom configurations

## Development Workflow

### 1. Feature Development
```bash
# Work on bash script enhancements
./bash/git-history-report.sh --preset today --format html > test.html
# Verify output and test new features

# Server development
cd server/
bun run dev
# Make changes, server auto-reloads

# Script integration testing
./scripts/generate-and-upload.sh --preset today --verbose
```

### 2. Testing Pipeline
```bash
# Test each component individually
./bash/git-history-report.sh --preset today --format html   # Bash script
cd server && bun run test:functionality                      # Server API
./scripts/upload-report.sh --help                           # Upload script

# Test full integration
./scripts/generate-and-upload.sh --preset last-week --verbose
```

### 3. Deployment Preparation
```bash
# Build production server
cd server/
bun run build
bun run typecheck
bun run lint

# Test production build
NODE_ENV=production bun run start

# Verify all scripts are executable
chmod +x bash/git-history-report.sh
chmod +x scripts/*.sh
```

## Environment Configuration

### Development Environment
```bash
# Server configuration
export PORT=3001
export NODE_ENV=development
export REPORT_TTL=3600

# Script configuration
export GIT_REPORT_SERVER_URL=http://localhost:3001
```

### Production Environment
```bash
# Server configuration
export PORT=3000
export HOST=0.0.0.0
export NODE_ENV=production
export REPORT_TTL=3600

# Script configuration
export GIT_REPORT_SERVER_URL=https://reports.company.com
```

## Troubleshooting

### Common Issues

**Server won't start**
```bash
cd server/
bun install          # Reinstall dependencies
bun run typecheck    # Check for TypeScript errors
lsof -i :3001        # Check if port is in use
```

**Scripts fail to execute**
```bash
chmod +x bash/git-history-report.sh scripts/*.sh   # Fix permissions
which jq             # Ensure jq is installed
which curl           # Ensure curl is available
```

**Reports not generating**
```bash
git status           # Ensure you're in a git repository
git log --oneline    # Verify commits exist in date range
./bash/git-history-report.sh --preset today --format html   # Test directly
```

### Debug Commands
```bash
# Server debugging
curl -v http://localhost:3001/health
curl -v http://localhost:3001/api/reports/health

# Script debugging
./scripts/upload-report.sh --help
echo "test" | ./scripts/upload-report.sh --verbose

# Report debugging
./bash/git-history-report.sh --preset today --format html | head -20
```

## Production Deployment

### Server Deployment
```bash
# Build and deploy server
cd server/
bun run build
NODE_ENV=production bun run start

# Docker deployment
docker build -t git-history-server .
docker run -p 3000:3000 -e NODE_ENV=production git-history-server
```

### Script Installation
```bash
# Make scripts available system-wide
sudo cp scripts/*.sh /usr/local/bin/
sudo cp bash/git-history-report.sh /usr/local/bin/

# Or add to PATH
export PATH=$PATH:/path/to/gitHistoryReporter/scripts:/path/to/gitHistoryReporter/bash
```

## Integration Examples

### CI/CD Pipeline
```yaml
# .github/workflows/weekly-report.yml
name: Weekly Team Report
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate Report
        run: |
          export GIT_REPORT_SERVER_URL=${{ secrets.REPORT_SERVER_URL }}
          URL=$(./scripts/generate-and-upload.sh --preset last-week --quiet)
          echo "Report URL: $URL" >> $GITHUB_STEP_SUMMARY
```

### Automated Daily Reports
```bash
# Add to crontab
0 9 * * * cd /path/to/repo && ./scripts/generate-and-upload.sh --preset yesterday --quiet | mail -s "Daily Git Report" team@company.com
```

---

**📚 Component Documentation:**
- `server/CLAUDE.md` - Server-specific development guide
- `server/README.md` - Server API documentation
- Main `README.md` - User-facing documentation and examples