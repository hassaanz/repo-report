import { writeFile, readFile, unlink, access, readdir } from 'fs/promises';
import { join } from 'path';
import type { ReportMetadata, CreateReportRequest, CreateReportResponse } from '@/types/report';
import {
  generateReportHash,
  generateFilename,
  generateContentHash,
  getFilenameFromHash,
  isValidReportHash
} from '@/utils/hash';

export class ReportService {
  private reportsDir: string;
  private metadata: Map<string, ReportMetadata> = new Map();
  private defaultTTL = 3600; // 1 hour in seconds

  constructor(reportsDir: string = './reports') {
    this.reportsDir = reportsDir;
    this.startCleanupInterval();
  }

  /**
   * Store a report and return metadata for accessing it
   */
  async createReport(request: CreateReportRequest): Promise<CreateReportResponse> {
    const currentEpoch = Math.floor(Date.now() / 1000);
    const ttl = request.ttl || this.defaultTTL;
    const expiresAt = currentEpoch + ttl;

    const reportHash = generateReportHash();
    const filename = generateFilename(reportHash, currentEpoch, expiresAt);
    const contentHash = generateContentHash(request.content);

    const filePath = join(this.reportsDir, filename);

    // Store the file
    await writeFile(filePath, request.content, 'utf-8');

    // Store metadata
    const metadata: ReportMetadata = {
      reportHash,
      filename,
      createdAt: currentEpoch,
      expiresAt,
      contentHash,
      size: Buffer.byteLength(request.content, 'utf-8')
    };

    this.metadata.set(reportHash, metadata);

    return {
      reportHash,
      url: `/r/${reportHash}`,
      expiresAt,
      createdAt: currentEpoch
    };
  }

  /**
   * Retrieve a report by its hash
   */
  async getReport(reportHash: string): Promise<string | null> {
    if (!isValidReportHash(reportHash)) {
      return null;
    }

    const metadata = this.metadata.get(reportHash);
    if (!metadata) {
      return null;
    }

    const currentEpoch = Math.floor(Date.now() / 1000);

    // Check if expired
    if (currentEpoch > metadata.expiresAt) {
      await this.deleteReport(reportHash);
      return null;
    }

    const filename = getFilenameFromHash(reportHash, metadata.createdAt, metadata.expiresAt);
    const filePath = join(this.reportsDir, filename);

    try {
      const content = await readFile(filePath, 'utf-8');
      return content;
    } catch (error) {
      // File not found, clean up metadata
      this.metadata.delete(reportHash);
      return null;
    }
  }

  /**
   * Check if a report exists and is not expired
   */
  async reportExists(reportHash: string): Promise<boolean> {
    if (!isValidReportHash(reportHash)) {
      return false;
    }

    const metadata = this.metadata.get(reportHash);
    if (!metadata) {
      return false;
    }

    const currentEpoch = Math.floor(Date.now() / 1000);
    return currentEpoch <= metadata.expiresAt;
  }

  /**
   * Get report metadata
   */
  getReportMetadata(reportHash: string): ReportMetadata | null {
    return this.metadata.get(reportHash) || null;
  }

  /**
   * Delete a specific report
   */
  async deleteReport(reportHash: string): Promise<boolean> {
    const metadata = this.metadata.get(reportHash);
    if (!metadata) {
      return false;
    }

    const filename = getFilenameFromHash(reportHash, metadata.createdAt, metadata.expiresAt);
    const filePath = join(this.reportsDir, filename);

    try {
      await unlink(filePath);
    } catch (error) {
      // File might already be deleted, that's ok
    }

    this.metadata.delete(reportHash);
    return true;
  }

  /**
   * Clean up expired reports
   */
  async cleanupExpiredReports(): Promise<number> {
    const currentEpoch = Math.floor(Date.now() / 1000);
    const expiredHashes: string[] = [];

    for (const [hash, metadata] of this.metadata.entries()) {
      if (currentEpoch > metadata.expiresAt) {
        expiredHashes.push(hash);
      }
    }

    for (const hash of expiredHashes) {
      await this.deleteReport(hash);
    }

    return expiredHashes.length;
  }

  /**
   * Get stats about stored reports
   */
  getStats() {
    const currentEpoch = Math.floor(Date.now() / 1000);
    let totalReports = 0;
    let expiredReports = 0;
    let totalSize = 0;

    for (const metadata of this.metadata.values()) {
      totalReports++;
      totalSize += metadata.size;

      if (currentEpoch > metadata.expiresAt) {
        expiredReports++;
      }
    }

    return {
      totalReports,
      activeReports: totalReports - expiredReports,
      expiredReports,
      totalSize,
      memoryUsage: this.metadata.size
    };
  }

  /**
   * Start automatic cleanup interval
   */
  private startCleanupInterval() {
    // Clean up every 5 minutes
    setInterval(async () => {
      const cleaned = await this.cleanupExpiredReports();
      if (cleaned > 0) {
        console.log(`Cleaned up ${cleaned} expired reports`);
      }
    }, 5 * 60 * 1000);
  }
}