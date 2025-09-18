export interface ReportMetadata {
  reportHash: string;
  filename: string;
  createdAt: number;
  expiresAt: number;
  contentHash: string;
  size: number;
}

export interface CreateReportRequest {
  content: string;
  ttl?: number; // Time to live in seconds, default 1 hour
}

export interface CreateReportResponse {
  reportHash: string;
  url: string;
  expiresAt: number;
  createdAt: number;
}

export interface ReportNotFoundError {
  error: 'REPORT_NOT_FOUND';
  message: string;
}

export interface ReportExpiredError {
  error: 'REPORT_EXPIRED';
  message: string;
}