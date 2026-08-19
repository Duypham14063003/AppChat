import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class AuditLogService {
  private readonly logger = new Logger('AuditLog');

  logAuthEvent(event: {
    type: string;
    userId?: string;
    email?: string;
    ip?: string;
    userAgent?: string;
    reason?: string;
    metadata?: Record<string, unknown>;
  }): void {
    this.logger.log(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        event: event.type,
        userId: event.userId,
        email: event.email,
        ip: event.ip,
        userAgent: event.userAgent,
        reason: event.reason,
        ...event.metadata,
      }),
    );
  }
}
