import { Injectable, Logger } from '@nestjs/common';
import { ChatService } from '../../chat/services/chat.service.js';
import { Poc } from '../entities/poc.entity.js';

@Injectable()
export class PocChatService {
  private readonly logger = new Logger(PocChatService.name);

  constructor(private readonly chat: ChatService) {}

  async project(
    poc: Poc,
    actorUserId: string,
    kind: string,
    changes?: Record<string, { previous: unknown; current: unknown }>,
    rethrowOnFailure = false,
  ): Promise<void> {
    if (!poc.working_conversation_id) return;
    try {
      await this.chat.createBusinessSystemMessage(
        poc.working_conversation_id,
        actorUserId,
        kind,
        this.metadata(poc, kind, changes),
      );
    } catch (error) {
      this.logger.error(
        `PoC chat projection failed for ${poc.id}: ${error instanceof Error ? error.message : String(error)}`,
      );
      if (rethrowOnFailure) throw error;
    }
  }

  metadata(
    poc: Poc,
    kind: string,
    changes?: Record<string, { previous: unknown; current: unknown }>,
  ): Record<string, unknown> {
    return {
      schema_version: 1,
      kind,
      poc_id: poc.id,
      code: poc.code,
      title: poc.title,
      customer_name: poc.customer_name,
      sale_user_id: poc.sale_user_id,
      developer_user_id: poc.developer_user_id,
      planned_start_at: poc.planned_start_at?.toISOString() ?? null,
      estimated_hours: poc.estimated_hours ? Number(poc.estimated_hours) : null,
      demo_at: poc.demo_at.toISOString(),
      status: poc.status,
      outcome: poc.outcome,
      changes: changes ?? null,
      deep_link: `/pocs/${poc.id}`,
    };
  }
}
