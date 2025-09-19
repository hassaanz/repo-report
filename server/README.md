# Git History Report Server

A TypeScript web server that generates and serves git repository history reports with beautiful badge generation and short-lived URLs.

## Features

- 🚀 **Fast**: Built with Bun runtime and Fastify framework
- 📊 **Rich Reports**: Generates comprehensive git history reports with statistics and visualizations
- 🏷️ **Beautiful Badges**: Creates PNG badges for GitHub README files with three variants (default, weekly, monthly)
- ⏱️ **Short-lived URLs**: Creates temporary URLs for secure report sharing
- 🎨 **Multiple Formats**: Supports HTML, Markdown, and ASCII output formats
- 🔍 **Flexible Filtering**: Filter by date ranges, authors, and predefined presets
- 🛡️ **Type Safe**: Full TypeScript support with comprehensive type definitions
- ⚡ **Loading States**: Instant loading images while badges generate in background
- 🎭 **Browser Automation**: Powered by Playwright for reliable badge generation

## Quick Start

### Prerequisites

- [Bun](https://bun.sh) runtime installed
- Git repository to analyze

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd gitHistoryReporter/server

# Install dependencies
bun install

# Install Playwright browsers (required for badge generation)
bun run playwright:install

# Start development server
bun run dev
```

The server will start on `http://localhost:3000`

## API Endpoints

### Create Report

```bash
POST /api/reports
Content-Type: application/json

{
  "content": "<html>...</html>",
  "ttl": 3600
}
```

**Response:**
```json
{
  "reportHash": "abc123def456",
  "url": "/r/abc123def456",
  "expiresAt": 1758281066,
  "createdAt": 1758277466
}
```

### View Report

```bash
GET /r/{reportHash}
```

Returns the HTML report content.

### Badge Generation

Generate beautiful PNG badges for your GitHub README:

#### Default Activity Badge
```bash
GET /api/reports/{reportHash}/badge
```
Returns a 320x120 PNG badge showing activity level, commits, lines added, and contributors.

#### Weekly Development Badge
```bash
GET /api/reports/{reportHash}/badge/weekly
```
Returns a 380x100 PNG badge with weekly development metrics and trends.

#### Monthly Overview Badge
```bash
GET /api/reports/{reportHash}/badge/monthly
```
Returns a 420x120 PNG badge showing comprehensive monthly development statistics.

### Health Endpoints

```bash
GET /health                    # Server health check
GET /api/reports/health        # Reports service health with statistics
GET /api/reports/{hash}/metadata  # Report metadata
```

## Badge Usage in GitHub README

After generating a report, embed badges in your README.md:

```markdown
<!-- Default Activity Badge -->
![Git Activity](http://localhost:3000/api/reports/{reportHash}/badge)

<!-- Weekly Development Badge -->
![Weekly Development](http://localhost:3000/api/reports/{reportHash}/badge/weekly)

<!-- Monthly Overview Badge -->
![Monthly Overview](http://localhost:3000/api/reports/{reportHash}/badge/monthly)
```

## Badge Features

### Activity Levels
Badges automatically determine activity level based on commits and lines changed:

- 🔥 **Peak** (50+ activity score): Red background
- ⚡ **High** (25+ activity score): Orange background
- 📈 **Active** (10+ activity score): Yellow background
- 📊 **Low** (3+ activity score): Green background
- 🧹 **Minimal** (<3 activity score): Blue background

*Activity Score = (commits × 2) + min(lines_added / 100, 10)*

### Badge Content

**Default Badge**: Activity level, commits, lines added, contributors
**Weekly Badge**: Period, commits, contributors, files changed, trend percentage
**Monthly Badge**: Period, commits, lines added, contributors, active days, velocity

## Environment Variables

```bash
PORT=3000                 # Server port
HOST=localhost           # Server host
NODE_ENV=development     # Environment mode
REPORT_TTL=3600         # Report URL expiration time (seconds)
```

## Development

### Scripts

```bash
bun run dev                    # Start development server with hot reload
bun run build                  # Build for production
bun run start                  # Start production server
bun test                       # Run tests
bun run test:functionality     # End-to-end functionality test
bun run lint                   # Lint code
bun run typecheck              # Type checking
bun run playwright:install     # Install Playwright browsers
bun run playwright:check       # Check if browsers are installed
```

### Project Structure

```
server/
├── src/
│   ├── routes/              # API route handlers
│   │   └── reports.ts       # All report and badge endpoints
│   ├── services/            # Business logic
│   │   ├── reportService.ts # Report storage and management
│   │   ├── indexService.ts  # Web interface generation
│   │   └── badgeService.ts  # Badge generation with Playwright
│   ├── templates/           # HTML templates for badges
│   │   ├── badge.html       # Default badge template
│   │   ├── badge-weekly.html    # Weekly badge template
│   │   ├── badge-monthly.html   # Monthly badge template
│   │   ├── badge-loading.html   # Loading state templates
│   │   └── index.html       # Web interface template
│   ├── types/               # TypeScript definitions
│   │   └── report.ts        # Report-related types
│   ├── utils/               # Utility functions
│   │   └── hash.ts          # Content hashing utilities
│   └── server.ts            # Main server entry point
├── badges/                  # Generated badge images (auto-created)
├── reports/                 # Stored report files (auto-created)
├── package.json
├── tsconfig.json
└── README.md
```

## Integration with Scripts

The server works seamlessly with the bash script ecosystem:

### Generate and Upload Reports
```bash
# From repository root
export GIT_REPORT_SERVER_URL=http://localhost:3000
./scripts/generate-and-upload.sh --preset last-week --verbose
```

### Direct Upload
```bash
# Pipe HTML content directly
echo "<html>...</html>" | ./scripts/upload-report.sh --verbose
```

## Badge Caching

- **First Request**: Returns loading image immediately (~1 second)
- **Background**: Actual badge generates using Playwright
- **Subsequent Requests**: Returns cached high-quality badge (~0.006s)
- **Cache Headers**: Proper HTTP caching with max-age=3600

## Examples

### Basic Report Creation

```javascript
const response = await fetch('http://localhost:3000/api/reports', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    content: '<html><body><h1>My Report</h1></body></html>',
    ttl: 3600
  })
});

const { reportHash, url } = await response.json();
console.log(`Report: http://localhost:3000${url}`);
console.log(`Badge: http://localhost:3000/api/reports/${reportHash}/badge`);
```

### Badge Usage in CI/CD

```yaml
# GitHub Actions example
- name: Generate Git Report Badge
  run: |
    URL=$(./scripts/generate-and-upload.sh --preset yesterday --quiet)
    HASH=$(echo "$URL" | sed 's/.*\/r\///')
    echo "![Git Activity](${URL/\/r\//\/api\/reports\/}/badge)" >> README.md
```

## Security Features

- Reports automatically expire after TTL
- Hash-based URLs prevent enumeration
- Input validation and sanitization
- No sensitive information logged
- Secure file storage with cleanup

## Troubleshooting

### Badge Generation Issues

```bash
# Check if Playwright browsers are installed
bun run playwright:check

# Install browsers if missing
bun run playwright:install

# Check server logs for errors
bun run dev
```

### Common Issues

1. **Badges not generating**: Run `bun run playwright:install`
2. **Reports not found**: Check TTL expiration
3. **Server won't start**: Check port availability with `lsof -i :3000`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Run the test suite: `bun run test:functionality`
6. Submit a pull request

## License

MIT License - see LICENSE file for details