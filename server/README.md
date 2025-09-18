# Git History Report Server

A TypeScript web server that generates and serves git repository history reports with short-lived URLs.

## Features

- 🚀 **Fast**: Built with Bun runtime and Fastify framework
- 📊 **Rich Reports**: Generates comprehensive git history reports with statistics and visualizations
- ⏱️ **Short-lived URLs**: Creates temporary URLs for secure report sharing
- 🎨 **Multiple Formats**: Supports HTML, Markdown, and ASCII output formats
- 🔍 **Flexible Filtering**: Filter by date ranges, authors, and predefined presets
- 🛡️ **Type Safe**: Full TypeScript support with comprehensive type definitions

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

# Start development server
bun run dev
```

The server will start on `http://localhost:3000`

## API Usage

### Generate a Report

```bash
# Generate HTML report for last week
curl -X POST http://localhost:3000/api/reports \
  -H "Content-Type: application/json" \
  -d '{
    "repositoryPath": "/path/to/your/repo",
    "preset": "last-week",
    "format": "html",
    "detailed": true
  }'

# Response
{
  "id": "abc123def456",
  "url": "http://localhost:3000/reports/abc123def456",
  "expiresAt": "2025-09-18T13:53:00Z"
}
```

### View a Report

Visit the returned URL in your browser to view the generated report.

## Configuration Options

### Report Generation Parameters

- `repositoryPath` (required): Path to the git repository
- `format`: Output format (`html`, `markdown`, `ascii`) - default: `html`
- `preset`: Quick date presets (`today`, `yesterday`, `last-week`, `last-month`, etc.)
- `since`: Custom start date (e.g., "2025-09-01", "1 week ago")
- `until`: Custom end date (e.g., "2025-09-18", "today")
- `author`: Filter by specific author
- `detailed`: Include detailed commit breakdown (default: false)

### Available Presets

- `today` - Today's commits only
- `yesterday` - Yesterday's commits only
- `last-week` - Last 7 days
- `this-week` - This week (Monday to today)
- `last-month` - Last 30 days
- `this-month` - This month (1st to today)
- `last-3-months` / `quarter` - Last 90 days
- `last-6-months` - Last 180 days
- `last-year` - Last 365 days
- `this-year` - This year (January 1st to today)
- `sprint` - Last 14 days

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
bun run dev        # Start development server with hot reload
bun run build      # Build for production
bun run start      # Start production server
bun test          # Run tests
bun run lint      # Lint code
bun run typecheck # Type checking
```

### Project Structure

```
server/
├── src/
│   ├── routes/          # API route handlers
│   │   ├── reports.ts   # Report generation endpoints
│   │   └── health.ts    # Health check endpoint
│   ├── services/        # Business logic
│   │   ├── reportService.ts     # Report generation service
│   │   └── storageService.ts    # Report storage and cleanup
│   ├── types/           # TypeScript definitions
│   │   ├── report.ts    # Report-related types
│   │   └── api.ts       # API request/response types
│   ├── utils/           # Utility functions
│   │   ├── validation.ts    # Input validation
│   │   └── processRunner.ts # Bash script execution
│   └── server.ts        # Main server entry point
├── package.json
├── tsconfig.json
└── README.md
```

## Examples

### Basic Usage

```javascript
// Generate a simple report
const response = await fetch('http://localhost:3000/api/reports', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    repositoryPath: '/path/to/repo',
    preset: 'last-week'
  })
});

const { url } = await response.json();
console.log(`Report available at: ${url}`);
```

### Advanced Filtering

```javascript
// Generate detailed report with custom date range
const response = await fetch('http://localhost:3000/api/reports', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    repositoryPath: '/path/to/repo',
    since: '2025-09-01',
    until: '2025-09-15',
    author: 'john.doe@example.com',
    format: 'html',
    detailed: true
  })
});
```

## Security Considerations

- Reports are automatically deleted after expiration
- Repository paths are validated to prevent directory traversal
- No sensitive git information is logged
- URLs are randomly generated and non-guessable

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Run the test suite
6. Submit a pull request

## License

MIT License - see LICENSE file for details