import { readFile } from 'fs/promises';
import { join } from 'path';

export class IndexService {
  private template: string | null = null;

  /**
   * Load and cache the HTML template
   */
  private async loadTemplate(): Promise<string> {
    if (!this.template) {
      const templatePath = join(__dirname, '../templates/index.html');
      this.template = await readFile(templatePath, 'utf-8');
    }
    return this.template;
  }

  /**
   * Generate the index page with dynamic content
   */
  async generateIndexPage(serverInfo: {
    status: string;
    uptime: number;
    port: number;
    version: string;
    baseUrl: string;
  }): Promise<string> {
    const template = await this.loadTemplate();

    // Format uptime in a human-readable way
    const formatUptime = (seconds: number): string => {
      const hours = Math.floor(seconds / 3600);
      const minutes = Math.floor((seconds % 3600) / 60);
      const secs = Math.floor(seconds % 60);

      if (hours > 0) {
        return `${hours}h ${minutes}m`;
      } else if (minutes > 0) {
        return `${minutes}m ${secs}s`;
      } else {
        return `${secs}s`;
      }
    };

    // Replace template variables
    return template
      .replace(/{{STATUS}}/g, serverInfo.status)
      .replace(/{{UPTIME}}/g, formatUptime(serverInfo.uptime))
      .replace(/{{PORT}}/g, serverInfo.port.toString())
      .replace(/{{VERSION}}/g, serverInfo.version)
      .replace(/{{BASE_URL}}/g, serverInfo.baseUrl);
  }
}