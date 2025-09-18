import Fastify from 'fastify';
import cors from '@fastify/cors';
import { reportRoutes } from '@/routes/reports';

const fastify = Fastify({
  logger: {
    level: process.env.NODE_ENV === 'production' ? 'info' : 'debug'
  }
});

// Register CORS
await fastify.register(cors, {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
});

// Register routes
await fastify.register(reportRoutes);

// Global error handler
fastify.setErrorHandler(async (error, request, reply) => {
  fastify.log.error(error);

  return reply.status(500).send({
    error: 'INTERNAL_SERVER_ERROR',
    message: 'An unexpected error occurred'
  });
});

// 404 handler
fastify.setNotFoundHandler(async (request, reply) => {
  return reply.status(404).send({
    error: 'NOT_FOUND',
    message: 'Route not found'
  });
});

// Health check endpoint
fastify.get('/health', async (request, reply) => {
  return reply.send({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Start server
const start = async () => {
  try {
    const host = process.env.HOST || 'localhost';
    const port = parseInt(process.env.PORT || '3000', 10);

    await fastify.listen({ host, port });

    console.log(`🚀 Git History Report Server running on http://${host}:${port}`);
    console.log(`📊 Submit reports to: http://${host}:${port}/api/reports`);
    console.log(`📋 View reports at: http://${host}:${port}/r/{reportHash}`);
    console.log(`❤️  Health check: http://${host}:${port}/health`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

// Graceful shutdown
const gracefulShutdown = async (signal: string) => {
  console.log(`\n📴 Received ${signal}, shutting down gracefully...`);

  try {
    await fastify.close();
    console.log('✅ Server closed successfully');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error during shutdown:', err);
    process.exit(1);
  }
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('💥 Uncaught Exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

start();