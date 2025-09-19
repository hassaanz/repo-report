import puppeteer from 'puppeteer';
import { readFile, writeFile } from 'fs/promises';
import { join } from 'path';
import type { ReportMetadata } from '@/types/report';
import { generateContentHash } from '@/utils/hash';

export interface BadgeData {
  icon: string;
  title: string;
  commits: number;
  linesAdded: number;
  contributors: number;
  activityLevel: string;
  activityClass: string;
}

export class BadgeService {
  private badgesDir: string;
  private templatesDir: string;

  constructor(badgesDir: string = './badges', templatesDir: string = './src/templates') {
    this.badgesDir = badgesDir;
    this.templatesDir = templatesDir;
  }

  /**
   * Extract summary data from HTML report content
   */
  extractReportSummary(htmlContent: string): BadgeData {
    // Parse key metrics from the HTML report
    const commits = this.extractNumber(htmlContent, /Total commits:\s*(\d+)/i) ||
                   this.extractNumber(htmlContent, /(\d+)\s*commits?/i) || 0;

    const linesAdded = this.extractNumber(htmlContent, /(\d+)\s*lines?\s*added/i) ||
                      this.extractNumber(htmlContent, /\+(\d+)/i) || 0;

    const contributors = this.extractNumber(htmlContent, /(\d+)\s*contributors?/i) ||
                        this.extractNumber(htmlContent, /(\d+)\s*authors?/i) || 1;

    // Extract period info to determine title
    let period = 'Last Week';
    if (htmlContent.includes('Today') || htmlContent.includes('today')) {
      period = 'Today';
    } else if (htmlContent.includes('Yesterday') || htmlContent.includes('yesterday')) {
      period = 'Yesterday';
    } else if (htmlContent.includes('This Week') || htmlContent.includes('this week')) {
      period = 'This Week';
    } else if (htmlContent.includes('Last Month') || htmlContent.includes('last month')) {
      period = 'Last Month';
    } else if (htmlContent.includes('Quarter') || htmlContent.includes('quarter')) {
      period = 'Quarter';
    }

    // Determine activity level based on commits
    const { activityLevel, activityClass, icon } = this.getActivityLevel(commits, linesAdded);

    return {
      icon,
      title: `Git Activity • ${period}`,
      commits,
      linesAdded,
      contributors,
      activityLevel,
      activityClass
    };
  }

  /**
   * Extract numeric value from HTML using regex
   */
  private extractNumber(html: string, regex: RegExp): number | null {
    const match = html.match(regex);
    if (match && match[1]) {
      const num = parseInt(match[1].replace(/,/g, ''), 10);
      return isNaN(num) ? null : num;
    }
    return null;
  }

  /**
   * Determine activity level and corresponding styling
   */
  private getActivityLevel(commits: number, linesAdded: number): { activityLevel: string; activityClass: string; icon: string } {
    const score = commits * 2 + Math.min(linesAdded / 100, 10);

    if (score >= 50) {
      return { activityLevel: 'Peak', activityClass: 'activity-peak', icon: '🔥' };
    } else if (score >= 25) {
      return { activityLevel: 'High', activityClass: 'activity-high', icon: '⚡' };
    } else if (score >= 10) {
      return { activityLevel: 'Active', activityClass: 'activity-moderate', icon: '📈' };
    } else if (score >= 3) {
      return { activityLevel: 'Low', activityClass: 'activity-low', icon: '📊' };
    } else {
      return { activityLevel: 'Minimal', activityClass: 'activity-minimal', icon: '🧹' };
    }
  }

  /**
   * Generate HTML content for badge
   */
  async generateBadgeHTML(badgeData: BadgeData): Promise<string> {
    const templatePath = join(this.templatesDir, 'badge.html');
    let template = await readFile(templatePath, 'utf-8');

    // Replace template variables
    template = template.replace(/{{icon}}/g, badgeData.icon);
    template = template.replace(/{{title}}/g, badgeData.title);
    template = template.replace(/{{commits}}/g, badgeData.commits.toString());
    template = template.replace(/{{linesAdded}}/g, badgeData.linesAdded.toLocaleString());
    template = template.replace(/{{contributors}}/g, badgeData.contributors.toString());
    template = template.replace(/{{activityLevel}}/g, badgeData.activityLevel);
    template = template.replace(/{{activityClass}}/g, badgeData.activityClass);

    return template;
  }

  /**
   * Generate badge image from HTML content
   */
  async generateBadgeImage(reportHash: string, htmlContent: string): Promise<string> {
    // Extract summary data
    const badgeData = this.extractReportSummary(htmlContent);

    // Generate badge HTML
    const badgeHTML = await this.generateBadgeHTML(badgeData);

    // Generate image filename based on content hash
    const contentHash = generateContentHash(badgeHTML);
    const imageFilename = `${reportHash}_${contentHash}.png`;
    const imagePath = join(this.badgesDir, imageFilename);

    // Check if image already exists
    try {
      await readFile(imagePath);
      return imageFilename; // Return existing image
    } catch {
      // Image doesn't exist, generate it
    }

    // Launch puppeteer and generate image
    const browser = await puppeteer.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
      const page = await browser.newPage();

      // Set viewport to match badge dimensions
      await page.setViewport({ width: 320, height: 120, deviceScaleFactor: 2 });

      // Set HTML content
      await page.setContent(badgeHTML, { waitUntil: 'networkidle0' });

      // Take screenshot
      const screenshot = await page.screenshot({
        type: 'png',
        omitBackground: false,
        clip: { x: 0, y: 0, width: 320, height: 120 }
      });

      // Save image
      await writeFile(imagePath, screenshot);

      return imageFilename;
    } finally {
      await browser.close();
    }
  }

  /**
   * Get badge image path
   */
  getBadgeImagePath(filename: string): string {
    return join(this.badgesDir, filename);
  }

  /**
   * Check if badge image exists
   */
  async badgeExists(filename: string): Promise<boolean> {
    try {
      await readFile(join(this.badgesDir, filename));
      return true;
    } catch {
      return false;
    }
  }
}