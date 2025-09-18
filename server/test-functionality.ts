#!/usr/bin/env bun

/**
 * Functional test script for Git History Report Server
 *
 * Tests:
 * 1. Store report with short expiry time
 * 2. Retrieve report and validate content matches
 * 3. Wait for expiry and ensure report is no longer accessible
 */

const SERVER_URL = process.env.SERVER_URL || 'http://localhost:3000';
const TEST_TTL = 5; // 5 seconds for quick testing

// Test data - simulated git history report HTML
const TEST_HTML_CONTENT = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Test Git History Report</title>
</head>
<body>
    <h1>📊 Git History Report</h1>
    <div class="summary">
        <h2>Summary Statistics</h2>
        <p>Total Commits: 42</p>
        <p>Lines Added: 1,337</p>
        <p>Lines Removed: 420</p>
    </div>
    <div class="contributors">
        <h2>Top Contributors</h2>
        <ul>
            <li>Alice Developer - 25 commits</li>
            <li>Bob Coder - 17 commits</li>
        </ul>
    </div>
    <p>Generated at: ${new Date().toISOString()}</p>
</body>
</html>`;

// Color codes for console output
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    reset: '\x1b[0m',
    bold: '\x1b[1m'
};

// Helper function for colored console output
function log(message: string, color: string = colors.reset) {
    console.log(`${color}${message}${colors.reset}`);
}

function logStep(step: number, message: string) {
    log(`${colors.bold}${colors.blue}Step ${step}:${colors.reset} ${message}`);
}

function logSuccess(message: string) {
    log(`${colors.green}✅ ${message}${colors.reset}`);
}

function logError(message: string) {
    log(`${colors.red}❌ ${message}${colors.reset}`);
}

function logWarning(message: string) {
    log(`${colors.yellow}⚠️  ${message}${colors.reset}`);
}

// HTTP helper functions
async function makeRequest(url: string, options: RequestInit = {}): Promise<Response> {
    try {
        const response = await fetch(url, {
            ...options,
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        });
        return response;
    } catch (error) {
        throw new Error(`Network error: ${error}`);
    }
}

// Test functions
async function testServerHealth(): Promise<boolean> {
    logStep(0, 'Checking server health...');

    try {
        const response = await makeRequest(`${SERVER_URL}/health`);

        if (!response.ok) {
            logError(`Server health check failed: ${response.status} ${response.statusText}`);
            return false;
        }

        const health = await response.json();
        logSuccess(`Server is healthy (uptime: ${Math.round(health.uptime)}s)`);
        return true;
    } catch (error) {
        logError(`Could not reach server: ${error}`);
        logWarning(`Make sure server is running at ${SERVER_URL}`);
        return false;
    }
}

async function createReport(): Promise<{ reportHash: string; url: string; expiresAt: number } | null> {
    logStep(1, `Creating report with ${TEST_TTL}s TTL...`);

    try {
        const response = await makeRequest(`${SERVER_URL}/api/reports`, {
            method: 'POST',
            body: JSON.stringify({
                content: TEST_HTML_CONTENT,
                ttl: TEST_TTL
            })
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({ error: 'Unknown' }));
            logError(`Failed to create report: ${response.status} - ${errorData.error || errorData.message || 'Unknown error'}`);
            return null;
        }

        const result = await response.json();

        logSuccess(`Report created successfully!`);
        log(`  📝 Report Hash: ${colors.cyan}${result.reportHash}${colors.reset}`);
        log(`  🔗 URL: ${colors.cyan}${result.url}${colors.reset}`);
        log(`  ⏰ Expires At: ${colors.cyan}${new Date(result.expiresAt * 1000).toISOString()}${colors.reset}`);

        return result;
    } catch (error) {
        logError(`Error creating report: ${error}`);
        return null;
    }
}

async function retrieveReport(reportHash: string): Promise<{ success: boolean; content?: string; status?: number }> {
    logStep(2, `Retrieving report by hash: ${reportHash}`);

    try {
        const response = await makeRequest(`${SERVER_URL}/r/${reportHash}`);

        if (!response.ok) {
            if (response.status === 404) {
                logWarning(`Report not found or expired (404)`);
                return { success: false, status: 404 };
            }

            logError(`Failed to retrieve report: ${response.status} ${response.statusText}`);
            return { success: false, status: response.status };
        }

        const content = await response.text();
        logSuccess(`Report retrieved successfully! (${content.length} bytes)`);

        return { success: true, content, status: 200 };
    } catch (error) {
        logError(`Error retrieving report: ${error}`);
        return { success: false };
    }
}

function validateContent(retrievedContent: string, originalContent: string): boolean {
    logStep(3, 'Validating content matches...');

    // Normalize whitespace for comparison
    const normalize = (str: string) => str.replace(/\s+/g, ' ').trim();

    const retrievedNormalized = normalize(retrievedContent);
    const originalNormalized = normalize(originalContent);

    if (retrievedNormalized === originalNormalized) {
        logSuccess('Content validation passed! Retrieved content matches original.');
        return true;
    } else {
        logError('Content validation failed! Retrieved content does not match original.');
        log(`  Expected length: ${originalNormalized.length}`);
        log(`  Actual length: ${retrievedNormalized.length}`);

        // Show first difference for debugging
        for (let i = 0; i < Math.min(originalNormalized.length, retrievedNormalized.length); i++) {
            if (originalNormalized[i] !== retrievedNormalized[i]) {
                log(`  First difference at position ${i}:`);
                log(`    Expected: "${originalNormalized.substring(i, i + 20)}..."`);
                log(`    Actual: "${retrievedNormalized.substring(i, i + 20)}..."`);
                break;
            }
        }
        return false;
    }
}

async function waitForExpiry(seconds: number): Promise<void> {
    logStep(4, `Waiting ${seconds + 1} seconds for report to expire...`);

    // Add 1 extra second to ensure expiry
    const waitTime = (seconds + 1) * 1000;

    for (let i = seconds + 1; i > 0; i--) {
        process.stdout.write(`\r⏳ Waiting... ${i} seconds remaining`);
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    process.stdout.write('\r⏳ Wait complete!                    \n');
    logSuccess('Wait period completed');
}

async function verifyExpiry(reportHash: string): Promise<boolean> {
    logStep(5, 'Verifying report has expired...');

    const result = await retrieveReport(reportHash);

    if (result.success) {
        logError('Report should have expired but is still accessible!');
        return false;
    } else if (result.status === 404) {
        logSuccess('Report correctly expired and is no longer accessible');
        return true;
    } else {
        logWarning(`Unexpected status code: ${result.status}`);
        return false;
    }
}

// Main test function
async function runTests(): Promise<void> {
    log(`${colors.bold}${colors.cyan}🧪 Git History Report Server - Functionality Test${colors.reset}`);
    log(`${colors.bold}Server URL: ${SERVER_URL}${colors.reset}`);
    log(`${colors.bold}Test TTL: ${TEST_TTL} seconds${colors.reset}\n`);

    let allTestsPassed = true;

    try {
        // Step 0: Health check
        const isHealthy = await testServerHealth();
        if (!isHealthy) {
            process.exit(1);
        }

        // Step 1: Create report
        const reportData = await createReport();
        if (!reportData) {
            logError('Could not create report, aborting tests');
            process.exit(1);
        }

        // Step 2: Retrieve report
        const retrieveResult = await retrieveReport(reportData.reportHash);
        if (!retrieveResult.success || !retrieveResult.content) {
            logError('Could not retrieve report, aborting tests');
            allTestsPassed = false;
        } else {
            // Step 3: Validate content
            const contentValid = validateContent(retrieveResult.content, TEST_HTML_CONTENT);
            if (!contentValid) {
                allTestsPassed = false;
            }
        }

        // Step 4: Wait for expiry
        await waitForExpiry(TEST_TTL);

        // Step 5: Verify expiry
        const expiryValid = await verifyExpiry(reportData.reportHash);
        if (!expiryValid) {
            allTestsPassed = false;
        }

    } catch (error) {
        logError(`Unexpected error during tests: ${error}`);
        allTestsPassed = false;
    }

    // Final results
    log('\n' + '='.repeat(60));
    if (allTestsPassed) {
        log(`${colors.bold}${colors.green}🎉 All tests passed! Server functionality is working correctly.${colors.reset}`);
        process.exit(0);
    } else {
        log(`${colors.bold}${colors.red}💥 Some tests failed! Check the output above for details.${colors.reset}`);
        process.exit(1);
    }
}

// Handle command line arguments
if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(`
Git History Report Server - Functionality Test

Usage:
  bun run test-functionality.ts [options]

Options:
  --help, -h     Show this help message

Environment Variables:
  SERVER_URL     Server base URL (default: http://localhost:3000)

Example:
  SERVER_URL=http://localhost:8080 bun run test-functionality.ts
`);
    process.exit(0);
}

// Run the tests
runTests().catch((error) => {
    logError(`Fatal error: ${error}`);
    process.exit(1);
});