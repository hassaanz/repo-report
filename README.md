# 📊 Git History Reporter

A comprehensive system for generating, serving, and sharing beautiful git repository history reports with rich visualizations and analytics.

## 🏗️ Project Structure

```
gitHistoryReporter/
├── bash/                          # Core report generation
│   └── git-history-report.sh     # Main bash script for generating reports
├── server/                        # Web server and API
│   ├── src/                      # TypeScript source code
│   ├── package.json              # Dependencies and scripts
│   └── README.md                 # Server-specific documentation
├── scripts/                       # Integration scripts
│   ├── upload-report.sh          # Upload reports to server
│   └── generate-and-upload.sh    # Generate and upload in one command
├── quick-report.sh               # One-command installer and report generator
└── README.md                      # This file
```

## ⚡ One-Command Quick Start

**Generate and share a git history report instantly without downloading anything:**

```bash
# Basic usage - generates last week's report and uploads to default server
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash

# With custom options
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash -s -- --preset last-month --verbose

# Custom server and detailed report
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash -s -- \
  --preset last-week --detailed --server https://reports.company.com
```

**That's it!** The script will automatically:
- 🔽 Download the necessary scripts from GitHub
- 📊 Generate a beautiful HTML report for your repository
- 🌐 Upload it to a server and return a shareable URL
- 🧹 Clean up temporary files

---

## 🚀 Full Installation Quick Start

If you want to set up the complete system locally:

### 1. Start the Server

```bash
cd server
bun install
bun run dev
```

The server will be available at http://localhost:3000 with a beautiful web interface.

### 2. Generate and Share a Report

```bash
# Option A: Use the one-command installer (recommended)
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash

# Option B: Generate and upload in one command (after cloning)
./scripts/generate-and-upload.sh --preset last-week --verbose

# Option C: Generate, then upload separately
./bash/git-history-report.sh --preset last-week --format html > report.html
cat report.html | ./scripts/upload-report.sh

# Option D: Use the web interface
# Visit http://localhost:3000 for full documentation and examples
```

## 🧩 Components

### 📈 Core Report Generator (`bash/git-history-report.sh`)

Generates comprehensive git history reports with:
- **Multiple Formats**: HTML, Markdown, ASCII
- **Rich Visualizations**: Activity indicators, contributor rankings, velocity metrics
- **Flexible Filtering**: Date ranges, authors, preset periods
- **Detailed Analytics**: Daily breakdowns, commit statistics, development patterns

**Key Features:**
- 🎨 Beautiful HTML reports with responsive design
- 📊 Activity level indicators (🔥🔥🔥🔥🔥 Peak → 🧹 Cleanup)
- 👥 Contributor analysis with role identification
- ⚡ Performance metrics and development velocity
- 🕒 12 preset date ranges (today, last-week, quarter, etc.)

### 🌐 Web Server (`server/`)

TypeScript/Fastify web server providing:
- **Report Storage**: Secure, short-lived URL generation
- **Web Interface**: Beautiful documentation and usage guide
- **RESTful API**: Complete endpoints for report management
- **Auto-Cleanup**: Automatic expiration of old reports

**Technologies:**
- **Runtime**: Bun
- **Framework**: Fastify
- **Language**: TypeScript
- **Features**: CORS, health checks, comprehensive error handling

### 🔧 Integration Scripts (`scripts/`)

Production-ready bash scripts for automation:

#### `upload-report.sh` - Report Uploader
- Accepts piped HTML content
- Uploads to server with configurable TTL
- Returns shareable URLs
- Comprehensive error handling and validation

#### `generate-and-upload.sh` - All-in-One Generator
- Generates reports using the bash script
- Automatically uploads to server
- Supports all report generation options
- Dry-run mode for testing

### ⚡ One-Command Installer (`quick-report.sh`)

Zero-installation solution for instant report generation:

#### `quick-report.sh` - One-Command Installer & Report Generator
- **Zero Setup Required**: Run directly from GitHub via curl
- **Automatic Downloads**: Fetches necessary scripts on-demand
- **Full Feature Support**: All git-history-report.sh and upload options
- **Clean Operation**: Automatic cleanup of temporary files
- **Environment Flexible**: Configurable GitHub repo, server URLs, and options
- **Production Ready**: Comprehensive error handling and progress reporting

**Usage:**
```bash
# Basic usage
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash

# With options
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/quick-report.sh | bash -s -- \
  --preset last-month --detailed --server https://my-server.com
```

## 📖 Usage Examples

### Basic Report Generation

```bash
# Today's activity
./bash/git-history-report.sh --preset today --format html

# Last week with details
./bash/git-history-report.sh --preset last-week --detailed --format html

# Custom date range for specific author
./bash/git-history-report.sh \
  --since "2025-09-01" \
  --until "2025-09-15" \
  --author "john.doe@company.com" \
  --format html
```

### Server Integration

```bash
# Set server URL
export GIT_REPORT_SERVER_URL="http://localhost:3001"

# Generate and upload weekly team report
./scripts/generate-and-upload.sh --preset last-week --verbose

# Upload existing report with custom TTL
cat existing-report.html | ./scripts/upload-report.sh --ttl 7200

# Save report locally without uploading
./scripts/generate-and-upload.sh --preset today --dry-run --save-local today.html
```

### Automation Examples

```bash
# Daily automated report (add to cron)
#!/bin/bash
cd /path/to/repo
export GIT_REPORT_SERVER_URL="https://reports.company.com"
URL=$(./scripts/generate-and-upload.sh --preset yesterday --quiet)
echo "Yesterday's report: $URL" | mail -s "Daily Git Report" team@company.com

# Weekly team summary
./scripts/generate-and-upload.sh \
  --preset last-week \
  --detailed \
  --verbose \
  --ttl 604800  # 1 week TTL
```

## 🎯 Available Presets

| Preset | Description | Use Case |
|--------|-------------|----------|
| `today` | Today's commits only | Daily standup reports |
| `yesterday` | Yesterday's commits | Daily summary emails |
| `last-week` | Last 7 days | Weekly team reviews |
| `this-week` | This week (Monday to today) | Current week progress |
| `last-month` | Last 30 days | Monthly team reports |
| `this-month` | This month (1st to today) | Month-to-date progress |
| `quarter` | Last 90 days | Quarterly business reviews |
| `sprint` | Last 14 days | Sprint retrospectives |
| `last-year` | Last 365 days | Annual reviews |
| `this-year` | This year (Jan 1st to today) | Year-to-date analysis |

## 📊 Report Features

### 🎨 Visual Elements
- **Activity Levels**: 🔥🔥🔥🔥🔥 Peak Development → 🧹 Code Cleanup
- **Contributor Rankings**: 🏆 Top performers with role identification
- **Daily Breakdown**: Commit activity with visual indicators
- **Statistics Cards**: Summary metrics with growth indicators

### 📈 Analytics
- **Development Velocity**: Commits per day, peak activity analysis
- **Contributor Analysis**: Role identification (Foundation Builder, Lead Developer, etc.)
- **Pattern Recognition**: Development phases (Feature Development, Maintenance, etc.)
- **Code Growth**: Net line changes with trend analysis

### 🎛️ Customization
- **Multiple Output Formats**: HTML (interactive), Markdown (portable), ASCII (terminal-friendly)
- **Flexible Filtering**: Date ranges, specific authors, repository paths
- **Detailed Mode**: Extended commit breakdown with file statistics
- **Custom TTL**: Configurable expiration for shared reports

## 🌐 Web Interface

The server provides a comprehensive web interface at the root URL with:

- **📋 Interactive Documentation**: Tabbed interface with examples
- **🚀 Usage Guide**: Step-by-step instructions with copy-paste commands
- **📖 API Reference**: Complete endpoint documentation
- **💡 Practical Examples**: Real-world automation scenarios
- **📊 Live Server Status**: Health monitoring and statistics

## 🔧 Development

### Server Development

```bash
cd server
bun install
bun run dev        # Development with hot reload
bun run build      # Production build
bun run start      # Production server
bun run test       # Run tests
bun run typecheck  # Type validation
```

### Testing

```bash
# Test server functionality
cd server
bun run test:functionality

# Test report generation
./bash/git-history-report.sh --preset today --format html > test.html

# Test upload pipeline
echo "<html>test</html>" | ./scripts/upload-report.sh --verbose
```

## 🔒 Security Considerations

- **Short-lived URLs**: Reports expire automatically (default: 1 hour)
- **Content Validation**: Input sanitization and size limits
- **Path Security**: Repository path validation prevents directory traversal
- **No Sensitive Data**: Git content analysis only, no credential exposure
- **CORS Protection**: Configurable cross-origin request policies

## 🚀 Production Deployment

### Environment Variables

```bash
# Server configuration
PORT=3000                          # Server port
HOST=localhost                     # Server host
NODE_ENV=production                # Environment mode
REPORT_TTL=3600                    # Default TTL in seconds

# Script configuration
GIT_REPORT_SERVER_URL=https://reports.company.com  # Server URL for scripts
```

### Docker Deployment

```dockerfile
# Example Dockerfile for server
FROM oven/bun:latest
WORKDIR /app
COPY server/ .
RUN bun install
EXPOSE 3000
CMD ["bun", "run", "start"]
```

### CI/CD Integration

```yaml
# Example GitHub Actions workflow
name: Generate Team Report
on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate Weekly Report
        run: |
          export GIT_REPORT_SERVER_URL="${{ secrets.REPORT_SERVER_URL }}"
          URL=$(./scripts/generate-and-upload.sh --preset last-week --quiet)
          echo "Weekly report available: $URL"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Add tests if applicable
5. Run the test suite: `bun run test`
6. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- **Documentation**: Visit the web interface for interactive docs
- **Issues**: Report bugs and feature requests on GitHub
- **Examples**: Check the `scripts/` directory for automation examples

---

**Built with 💙 using Bun, TypeScript, Fastify, and Bash**