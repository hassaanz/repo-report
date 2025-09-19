# Git History Reporter Badge Usage

The Git History Reporter now supports generating beautiful summary badges that can be embedded in GitHub README files and other documentation.

## Endpoint

```
GET /api/reports/{reportHash}/badge
```

Returns a PNG image (320x120 @ 2x resolution) summarizing the git activity from the report.

## Usage in GitHub README

After generating and uploading a report, you can embed the badge in your README.md:

```markdown
![Git Activity Badge](http://localhost:3001/api/reports/d76c1b981a12d02fd71877ebe4d6e8bf/badge)
```

## Example Badge

The badge displays:
- 📊 **Title**: Git Activity • {Period} (Today, Last Week, etc.)
- 🔢 **Commits**: Total number of commits
- ➕ **Lines Added**: Total lines of code added
- 👥 **Contributors**: Number of unique contributors
- 🔥 **Activity Level**: Peak, High, Active, Low, or Minimal

## Activity Levels

The badge automatically determines activity level based on commits and lines changed:

- 🔥 **Peak** (50+ activity score): Red background
- ⚡ **High** (25+ activity score): Orange background
- 📈 **Active** (10+ activity score): Yellow background
- 📊 **Low** (3+ activity score): Green background
- 🧹 **Minimal** (<3 activity score): Blue background

*Activity Score = (commits × 2) + min(lines_added / 100, 10)*

## Features

- ✅ **Automatic Caching**: Images are cached based on content hash
- ✅ **Same TTL as Reports**: Badges expire when the parent report expires
- ✅ **GitHub-Ready**: Perfect size for README badges (320x120 @ 2x DPI)
- ✅ **Responsive Design**: Clean, professional appearance
- ✅ **Activity Indicators**: Color-coded activity levels

## Integration Example

```bash
# Generate a report and get the URL
URL=$(./scripts/generate-and-upload.sh --preset last-week --quiet)

# Extract the report hash from the URL
HASH=$(echo "$URL" | sed 's/.*\/r\///')

# Use the badge in your README
echo "![Weekly Activity](${URL/\/r\//\/api\/reports\/}/badge)" >> README.md
```

## Automation Example

```yaml
# GitHub Actions workflow to update README badge
name: Update Git Activity Badge
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight

jobs:
  update-badge:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate Report and Update Badge
        run: |
          # Generate yesterday's report
          URL=$(./scripts/generate-and-upload.sh --preset yesterday --quiet)
          HASH=$(echo "$URL" | sed 's/.*\/r\///')

          # Update README with new badge
          sed -i "s|api/reports/.*/badge|api/reports/$HASH/badge|g" README.md

          # Commit if changed
          if ! git diff --exit-code README.md; then
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git add README.md
            git commit -m "Update git activity badge"
            git push
          fi
```

This creates a self-updating README badge that shows daily git activity for your repository!