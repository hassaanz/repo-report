import { chromium } from 'playwright';
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

export interface WeeklyBadgeData {
  icon: string;
  title: string;
  period: string;
  commits: number;
  contributors: number;
  filesChanged: number;
  trend: string;
  trendClass: string;
}

export interface MonthlyBadgeData {
  icon: string;
  title: string;
  period: string;
  commits: number;
  linesAdded: number;
  contributors: number;
  activeDays: number;
  activityLevel: string;
  activityClass: string;
  activityIcon: string;
  velocity: string;
}

export type BadgeType = 'default' | 'weekly' | 'monthly';

export class BadgeService {
  private badgesDir: string;
  private templatesDir: string;
  private generationQueue: Map<string, Promise<string>> = new Map();

  constructor(badgesDir: string = './badges', templatesDir: string = './src/templates') {
    this.badgesDir = badgesDir;
    this.templatesDir = templatesDir;
  }

  /**
   * Extract weekly overview data from HTML report content
   */
  extractWeeklyData(htmlContent: string): WeeklyBadgeData {
    const commits = this.extractNumber(htmlContent, /Total commits:\s*(\d+)/i) ||
                   this.extractNumber(htmlContent, /(\d+)\s*commits?/i) || 0;

    const contributors = this.extractNumber(htmlContent, /(\d+)\s*contributors?/i) ||
                        this.extractNumber(htmlContent, /(\d+)\s*authors?/i) || 1;

    const filesChanged = this.extractNumber(htmlContent, /(\d+)\s*files?\s*changed/i) ||
                        this.extractNumber(htmlContent, /Modified files:\s*(\d+)/i) || 0;

    // Determine period
    let period = 'Last 7 days';
    if (htmlContent.includes('This Week') || htmlContent.includes('this week')) {
      period = 'This week';
    } else if (htmlContent.includes('Last Week') || htmlContent.includes('last week')) {
      period = 'Last week';
    }

    // Calculate trend (simplified)
    const { trend, trendClass } = this.calculateTrend(commits, contributors);

    return {
      icon: '📈',
      title: 'Weekly Development',
      period,
      commits,
      contributors,
      filesChanged,
      trend,
      trendClass
    };
  }

  /**
   * Extract monthly overview data from HTML report content
   */
  extractMonthlyData(htmlContent: string): MonthlyBadgeData {
    const commits = this.extractNumber(htmlContent, /Total commits:\s*(\d+)/i) ||
                   this.extractNumber(htmlContent, /(\d+)\s*commits?/i) || 0;

    const linesAdded = this.extractNumber(htmlContent, /(\d+)\s*lines?\s*added/i) ||
                      this.extractNumber(htmlContent, /\+(\d+)/i) || 0;

    const contributors = this.extractNumber(htmlContent, /(\d+)\s*contributors?/i) ||
                        this.extractNumber(htmlContent, /(\d+)\s*authors?/i) || 1;

    // Extract active days (count of days with commits)
    const activeDays = this.extractActiveDays(htmlContent);

    // Determine period
    let period = 'Last 30 days';
    if (htmlContent.includes('This Month') || htmlContent.includes('this month')) {
      period = 'This month';
    } else if (htmlContent.includes('Last Month') || htmlContent.includes('last month')) {
      period = 'Last month';
    } else if (htmlContent.includes('Quarter') || htmlContent.includes('quarter')) {
      period = 'This quarter';
    }

    // Calculate activity level and velocity
    const { activityLevel, activityClass, activityIcon } = this.getActivityLevel(commits, linesAdded);
    const velocity = activeDays > 0 ? (commits / activeDays).toFixed(1) : '0';

    return {
      icon: '📊',
      title: 'Monthly Overview',
      period,
      commits,
      linesAdded,
      contributors,
      activeDays,
      activityLevel,
      activityClass,
      activityIcon,
      velocity
    };
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
   * Calculate trend for weekly badges
   */
  private calculateTrend(commits: number, contributors: number): { trend: string; trendClass: string } {
    // Simple trend calculation based on commit activity
    const score = commits + contributors * 2;

    if (score >= 20) {
      return { trend: '+15%', trendClass: 'trend-up' };
    } else if (score >= 10) {
      return { trend: '+8%', trendClass: 'trend-up' };
    } else if (score >= 5) {
      return { trend: 'Stable', trendClass: 'trend-stable' };
    } else {
      return { trend: '-5%', trendClass: 'trend-down' };
    }
  }

  /**
   * Extract active days from HTML content
   */
  private extractActiveDays(htmlContent: string): number {
    // Try to count days with activity from the HTML
    // Look for daily breakdown sections or date patterns
    const dayMatches = htmlContent.match(/(\d{4}-\d{2}-\d{2})/g);
    if (dayMatches) {
      // Count unique dates
      const uniqueDays = new Set(dayMatches);
      return Math.min(uniqueDays.size, 31); // Cap at 31 days
    }

    // Fallback: estimate based on commits (rough approximation)
    const commits = this.extractNumber(htmlContent, /(\d+)\s*commits?/i) || 0;
    if (commits >= 30) return Math.min(Math.floor(commits / 2), 30);
    if (commits >= 15) return Math.min(Math.floor(commits / 1.5), 20);
    if (commits >= 5) return Math.min(commits, 15);
    return Math.min(commits, 7);
  }

  /**
   * Determine activity level and corresponding styling
   */
  private getActivityLevel(commits: number, linesAdded: number): { activityLevel: string; activityClass: string; icon: string; activityIcon?: string } {
    const score = commits * 2 + Math.min(linesAdded / 100, 10);

    if (score >= 50) {
      return { activityLevel: 'Peak', activityClass: 'activity-peak', icon: '🔥', activityIcon: '🔥' };
    } else if (score >= 25) {
      return { activityLevel: 'High', activityClass: 'activity-high', icon: '⚡', activityIcon: '⚡' };
    } else if (score >= 10) {
      return { activityLevel: 'Active', activityClass: 'activity-moderate', icon: '📈', activityIcon: '📈' };
    } else if (score >= 3) {
      return { activityLevel: 'Low', activityClass: 'activity-low', icon: '📊', activityIcon: '📊' };
    } else {
      return { activityLevel: 'Minimal', activityClass: 'activity-minimal', icon: '🧹', activityIcon: '🧹' };
    }
  }

  /**
   * Generate HTML content for badge
   */
  async generateBadgeHTML(badgeData: BadgeData | WeeklyBadgeData | MonthlyBadgeData, badgeType: BadgeType = 'default'): Promise<string> {
    let templateName = 'badge.html';
    if (badgeType === 'weekly') templateName = 'badge-weekly.html';
    if (badgeType === 'monthly') templateName = 'badge-monthly.html';

    const templatePath = join(this.templatesDir, templateName);
    let template = await readFile(templatePath, 'utf-8');

    if (badgeType === 'default') {
      const data = badgeData as BadgeData;
      template = template.replace(/{{icon}}/g, data.icon);
      template = template.replace(/{{title}}/g, data.title);
      template = template.replace(/{{commits}}/g, data.commits.toString());
      template = template.replace(/{{linesAdded}}/g, data.linesAdded.toLocaleString());
      template = template.replace(/{{contributors}}/g, data.contributors.toString());
      template = template.replace(/{{activityLevel}}/g, data.activityLevel);
      template = template.replace(/{{activityClass}}/g, data.activityClass);
    } else if (badgeType === 'weekly') {
      const data = badgeData as WeeklyBadgeData;
      template = template.replace(/{{icon}}/g, data.icon);
      template = template.replace(/{{title}}/g, data.title);
      template = template.replace(/{{period}}/g, data.period);
      template = template.replace(/{{commits}}/g, data.commits.toString());
      template = template.replace(/{{contributors}}/g, data.contributors.toString());
      template = template.replace(/{{filesChanged}}/g, data.filesChanged.toString());
      template = template.replace(/{{trend}}/g, data.trend);
      template = template.replace(/{{trendClass}}/g, data.trendClass);
    } else if (badgeType === 'monthly') {
      const data = badgeData as MonthlyBadgeData;
      template = template.replace(/{{icon}}/g, data.icon);
      template = template.replace(/{{title}}/g, data.title);
      template = template.replace(/{{period}}/g, data.period);
      template = template.replace(/{{commits}}/g, data.commits.toString());
      template = template.replace(/{{linesAdded}}/g, data.linesAdded.toLocaleString());
      template = template.replace(/{{contributors}}/g, data.contributors.toString());
      template = template.replace(/{{activeDays}}/g, data.activeDays.toString());
      template = template.replace(/{{activityLevel}}/g, data.activityLevel);
      template = template.replace(/{{activityClass}}/g, data.activityClass);
      template = template.replace(/{{activityIcon}}/g, data.activityIcon);
      template = template.replace(/{{velocity}}/g, data.velocity);
    }

    return template;
  }

  /**
   * Generate loading badge image
   */
  async generateLoadingBadge(badgeType: BadgeType = 'default'): Promise<Buffer> {
    let templateName = 'badge-loading.html';
    let dimensions = { width: 320, height: 120 };

    if (badgeType === 'weekly') {
      templateName = 'badge-loading-weekly.html';
      dimensions = { width: 380, height: 100 };
    } else if (badgeType === 'monthly') {
      templateName = 'badge-loading-monthly.html';
      dimensions = { width: 420, height: 120 };
    }

    const templatePath = join(this.templatesDir, templateName);
    const loadingHTML = await readFile(templatePath, 'utf-8');

    // Launch chromium and generate loading image
    const browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
      const page = await browser.newPage();

      // Set viewport to match badge dimensions
      await page.setViewportSize({
        width: dimensions.width,
        height: dimensions.height
      });

      // Set HTML content
      await page.setContent(loadingHTML, { waitUntil: 'networkidle' });

      // Take screenshot
      const screenshot = await page.screenshot({
        type: 'png',
        clip: { x: 0, y: 0, width: dimensions.width, height: dimensions.height }
      });

      return screenshot;
    } finally {
      await browser.close();
    }
  }

  /**
   * Generate badge image from HTML content (with background generation support)
   */
  async generateBadgeImage(reportHash: string, htmlContent: string, badgeType: BadgeType = 'default'): Promise<string> {
    // Extract appropriate data based on badge type
    let badgeData: BadgeData | WeeklyBadgeData | MonthlyBadgeData;
    let dimensions = { width: 320, height: 120 };

    if (badgeType === 'weekly') {
      badgeData = this.extractWeeklyData(htmlContent);
      dimensions = { width: 380, height: 100 };
    } else if (badgeType === 'monthly') {
      badgeData = this.extractMonthlyData(htmlContent);
      dimensions = { width: 420, height: 120 };
    } else {
      badgeData = this.extractReportSummary(htmlContent);
    }

    // Generate badge HTML
    const badgeHTML = await this.generateBadgeHTML(badgeData, badgeType);

    return this.generateBadgeImageInternal(reportHash, badgeData, badgeType, dimensions);
  }

  /**
   * Get badge image with loading support
   */
  async getBadgeImageWithLoading(reportHash: string, htmlContent: string, badgeType: BadgeType = 'default'): Promise<{ buffer: Buffer; isLoading: boolean }> {
    // Generate cache key
    const badgeHTML = await this.generateBadgeHTMLForCaching(reportHash, htmlContent, badgeType);
    const contentHash = generateContentHash(badgeHTML);
    const imageFilename = `${reportHash}_${badgeType}_${contentHash}.png`;
    const imagePath = join(this.badgesDir, imageFilename);

    // Check if image already exists
    try {
      const existingImage = await readFile(imagePath);
      return { buffer: existingImage, isLoading: false };
    } catch {
      // Image doesn't exist, start background generation and return loading image
      const generationKey = `${reportHash}_${badgeType}`;

      // Check if generation is already in progress
      if (!this.generationQueue.has(generationKey)) {
        const generationPromise = this.generateBadgeImage(reportHash, htmlContent, badgeType);
        this.generationQueue.set(generationKey, generationPromise);

        // Clean up from queue when done
        generationPromise.finally(() => {
          this.generationQueue.delete(generationKey);
        });
      }

      // Return loading image
      const loadingBuffer = await this.generateLoadingBadge(badgeType);
      return { buffer: loadingBuffer, isLoading: true };
    }
  }

  /**
   * Generate badge HTML for caching purposes
   */
  private async generateBadgeHTMLForCaching(reportHash: string, htmlContent: string, badgeType: BadgeType): Promise<string> {
    let badgeData: BadgeData | WeeklyBadgeData | MonthlyBadgeData;

    if (badgeType === 'weekly') {
      badgeData = this.extractWeeklyData(htmlContent);
    } else if (badgeType === 'monthly') {
      badgeData = this.extractMonthlyData(htmlContent);
    } else {
      badgeData = this.extractReportSummary(htmlContent);
    }

    return this.generateBadgeHTML(badgeData, badgeType);
  }

  /**
   * Internal badge generation method
   */
  private async generateBadgeImageInternal(
    reportHash: string,
    badgeData: BadgeData | WeeklyBadgeData | MonthlyBadgeData,
    badgeType: BadgeType,
    dimensions: { width: number; height: number }
  ): Promise<string> {
    // Generate badge HTML
    const badgeHTML = await this.generateBadgeHTML(badgeData, badgeType);

    // Generate image filename based on content hash and type
    const contentHash = generateContentHash(badgeHTML);
    const imageFilename = `${reportHash}_${badgeType}_${contentHash}.png`;
    const imagePath = join(this.badgesDir, imageFilename);

    // Check if image already exists
    try {
      await readFile(imagePath);
      return imageFilename; // Return existing image
    } catch {
      // Image doesn't exist, generate it
    }

    // Launch chromium and generate image
    const browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
      const page = await browser.newPage();

      // Set viewport to match badge dimensions
      await page.setViewportSize({
        width: dimensions.width,
        height: dimensions.height
      });

      // Set HTML content
      await page.setContent(badgeHTML, { waitUntil: 'networkidle' });

      // Take screenshot
      const screenshot = await page.screenshot({
        type: 'png',
        clip: { x: 0, y: 0, width: dimensions.width, height: dimensions.height }
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