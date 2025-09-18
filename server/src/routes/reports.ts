import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import type { CreateReportRequest, CreateReportResponse } from '@/types/report';
import { ReportService } from '@/services/reportService';
import { IndexService } from '@/services/indexService';

export async function reportRoutes(fastify: FastifyInstance) {
  const reportService = new ReportService();
  const indexService = new IndexService();

  // Index page route
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const host = request.headers.host || 'localhost:3000';
      const protocol = request.headers['x-forwarded-proto'] || 'http';
      const baseUrl = `${protocol}://${host}`;

      const indexHtml = await indexService.generateIndexPage({
        status: '🟢 Healthy',
        uptime: process.uptime(),
        port: parseInt(process.env.PORT || '3000', 10),
        version: process.env.npm_package_version || '1.0.0',
        baseUrl
      });

      reply.header('Content-Type', 'text/html; charset=utf-8');
      return reply.send(indexHtml);
    } catch (error) {
      console.error('Error serving index page:', error);
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Failed to load index page'
      });
    }
  });

  // Route to accept script output and return report hash
  fastify.post<{
    Body: CreateReportRequest;
    Reply: CreateReportResponse | { error: string; message: string };
  }>('/api/reports', async (request: FastifyRequest<{ Body: CreateReportRequest }>, reply: FastifyReply) => {
    try {
      const { content, ttl } = request.body;

      // Validate content
      if (!content || typeof content !== 'string') {
        return reply.status(400).send({
          error: 'INVALID_CONTENT',
          message: 'Content is required and must be a string'
        });
      }

      // Validate content is not empty
      if (content.trim().length === 0) {
        return reply.status(400).send({
          error: 'EMPTY_CONTENT',
          message: 'Content cannot be empty'
        });
      }

      // Validate TTL if provided
      if (ttl !== undefined && (typeof ttl !== 'number' || ttl <= 0 || ttl > 86400)) {
        return reply.status(400).send({
          error: 'INVALID_TTL',
          message: 'TTL must be a positive number and not exceed 24 hours (86400 seconds)'
        });
      }

      // Create the report
      const result = await reportService.createReport({ content, ttl });

      return reply.status(201).send(result);
    } catch (error) {
      console.error('Error creating report:', error);
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Failed to create report'
      });
    }
  });

  // Route to serve reports by hash
  fastify.get<{
    Params: { reportHash: string };
  }>('/r/:reportHash', async (request: FastifyRequest<{ Params: { reportHash: string } }>, reply: FastifyReply) => {
    try {
      const { reportHash } = request.params;

      // Validate hash format
      if (!reportHash || !/^[a-f0-9]{32}$/i.test(reportHash)) {
        return reply.status(400).send({
          error: 'INVALID_HASH',
          message: 'Invalid report hash format'
        });
      }

      // Get the report content
      const content = await reportService.getReport(reportHash);

      if (!content) {
        return reply.status(404).send({
          error: 'REPORT_NOT_FOUND',
          message: 'Report not found or has expired'
        });
      }

      // Set appropriate headers for HTML content
      reply.header('Content-Type', 'text/html; charset=utf-8');
      reply.header('Cache-Control', 'no-cache, no-store, must-revalidate');
      reply.header('Pragma', 'no-cache');
      reply.header('Expires', '0');

      return reply.send(content);
    } catch (error) {
      console.error('Error serving report:', error);
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Failed to retrieve report'
      });
    }
  });

  // Health check endpoint for reports service
  fastify.get('/api/reports/health', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const stats = reportService.getStats();
      return reply.send({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        stats
      });
    } catch (error) {
      console.error('Health check error:', error);
      return reply.status(500).send({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: 'Service unavailable'
      });
    }
  });

  // Get report metadata (for debugging/monitoring)
  fastify.get<{
    Params: { reportHash: string };
  }>('/api/reports/:reportHash/metadata', async (request: FastifyRequest<{ Params: { reportHash: string } }>, reply: FastifyReply) => {
    try {
      const { reportHash } = request.params;

      if (!reportHash || !/^[a-f0-9]{32}$/i.test(reportHash)) {
        return reply.status(400).send({
          error: 'INVALID_HASH',
          message: 'Invalid report hash format'
        });
      }

      const metadata = reportService.getReportMetadata(reportHash);

      if (!metadata) {
        return reply.status(404).send({
          error: 'REPORT_NOT_FOUND',
          message: 'Report not found'
        });
      }

      return reply.send(metadata);
    } catch (error) {
      console.error('Error getting report metadata:', error);
      return reply.status(500).send({
        error: 'INTERNAL_ERROR',
        message: 'Failed to retrieve report metadata'
      });
    }
  });
}