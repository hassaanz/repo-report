import { createHash, randomBytes } from 'crypto';

/**
 * Generate a filename hash from report content and timestamps
 * f(reportHash, currentEpoch, expireEpoch) = filename
 */
export function generateFilename(reportHash: string, currentEpoch: number, expireEpoch: number): string {
  const combined = `${reportHash}-${currentEpoch}-${expireEpoch}`;
  return createHash('sha256').update(combined).digest('hex') + '.html';
}

/**
 * Generate a public report hash that can be used in URLs
 * This is a shorter, URL-friendly hash
 */
export function generateReportHash(): string {
  return randomBytes(16).toString('hex');
}

/**
 * Reverse function to get filename from report hash and timestamps
 * This is the main function: f(reportHash, currentEpoch, expireEpoch) = fn
 */
export function getFilenameFromHash(reportHash: string, currentEpoch: number, expireEpoch: number): string {
  return generateFilename(reportHash, currentEpoch, expireEpoch);
}

/**
 * Generate a content hash from the report HTML for deduplication
 */
export function generateContentHash(content: string): string {
  return createHash('md5').update(content).digest('hex');
}

/**
 * Validate if a report hash is in the correct format
 */
export function isValidReportHash(hash: string): boolean {
  return /^[a-f0-9]{32}$/i.test(hash);
}