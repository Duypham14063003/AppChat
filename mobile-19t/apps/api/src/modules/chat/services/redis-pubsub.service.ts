import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Redis from 'ioredis';
import type { WebSocket } from 'ws';
import { ConversationMember } from '../entities/conversation-member.entity.js';
import { ConnectionManager } from './connection-manager.service.js';

@Injectable()
export class RedisPubSubService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisPubSubService.name);
  private publisher!: Redis;
  private subscriber!: Redis;
  private readonly channelRefCount = new Map<string, number>();
  private readonly activeChannels = new Set<string>();

  constructor(
    private readonly config: ConfigService,
    private readonly connectionManager: ConnectionManager,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
  ) {}

  onModuleInit(): void {
    const redisOpts = {
      host: this.config.get('REDIS_HOST', 'localhost'),
      port: this.config.get<number>('REDIS_PORT', 6379),
      retryStrategy: (times: number) => Math.min(times * 1000, 30000),
    };

    this.publisher = new Redis(redisOpts);
    this.subscriber = new Redis(redisOpts);

    this.subscriber.on('message', (channel: string, message: string) => {
      this.handleMessage(channel, message);
    });

    this.subscriber.on('error', (err) => {
      this.logger.error(`Redis subscriber error: ${err.message}`);
    });

    this.subscriber.on('reconnecting', () => {
      this.logger.warn('Redis subscriber reconnecting...');
    });

    // Re-subscribe to all active channels on reconnect
    this.subscriber.on('connect', () => {
      if (this.activeChannels.size > 0) {
        this.logger.log(
          `Re-subscribing to ${this.activeChannels.size} channels`,
        );
        for (const channel of this.activeChannels) {
          this.subscriber.subscribe(channel).catch((err) => {
            this.logger.error(
              `Re-subscribe failed for ${channel}: ${err.message}`,
            );
          });
        }
      }
    });
  }

  // --- Publish ---

  async publish(
    convId: string,
    message: Record<string, unknown>,
  ): Promise<void> {
    const channel = `chat:conv:${convId}`;
    await this.publisher.publish(channel, JSON.stringify(message));
  }

  // --- Subscribe / Unsubscribe with ref counting ---

  private async subscribe(channel: string): Promise<void> {
    const count = (this.channelRefCount.get(channel) || 0) + 1;
    this.channelRefCount.set(channel, count);
    if (count === 1) {
      await this.subscriber.subscribe(channel);
      this.activeChannels.add(channel);
    }
  }

  private async unsubscribe(channel: string): Promise<void> {
    const count = (this.channelRefCount.get(channel) || 0) - 1;
    if (count <= 0) {
      this.channelRefCount.delete(channel);
      this.activeChannels.delete(channel);
      await this.subscriber.unsubscribe(channel);
    } else {
      this.channelRefCount.set(channel, count);
    }
  }

  // --- User-level subscription management ---

  async subscribeUser(userId: string): Promise<void> {
    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    for (const m of memberships) {
      await this.subscribe(`chat:conv:${m.conv_id}`);
    }
  }

  async unsubscribeUser(userId: string): Promise<void> {
    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    for (const m of memberships) {
      await this.unsubscribe(`chat:conv:${m.conv_id}`);
    }
  }

  async subscribeConversation(convId: string): Promise<void> {
    await this.subscribe(`chat:conv:${convId}`);
  }

  // --- Fan-out handler ---

  private handleMessage(channel: string, raw: string): void {
    try {
      const data = JSON.parse(raw);
      const convId = channel.replace('chat:conv:', '');
      const senderId = data.sender_id as string;
      const senderSocket = data._senderSocket as string | undefined;

      // Remove internal field before sending to clients
      delete data._senderSocket;

      // Find all members of this conversation who are online on this instance
      // We need to query memberRepo, but this is sync handler — use cached approach
      // Instead, iterate all connected users and check if they have connections
      this.fanOutToConversationMembers(convId, senderId, senderSocket, data);
    } catch (err: any) {
      this.logger.error(`Failed to handle Redis message: ${err.message}`);
    }
  }

  private async fanOutToConversationMembers(
    convId: string,
    senderId: string,
    senderSocketId: string | undefined,
    data: Record<string, unknown>,
  ): Promise<void> {
    const members = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id'],
    });

    // Use custom event name if provided, otherwise default to 'new_message'
    const eventName = (data._event as string) || 'new_message';
    delete data._event;

    const envelope = JSON.stringify({ event: eventName, data });

    for (const member of members) {
      // Skip sender for new_message (they already have it) and typing (no self-indicator)
      if (
        member.user_id === senderId &&
        (eventName === 'new_message' || eventName === 'typing')
      )
        continue;
      const sockets = this.connectionManager.getConnections(member.user_id);
      if (!sockets) continue;
      for (const socket of sockets) {
        if (socket.readyState === 1) {
          // OPEN
          socket.send(envelope);
        }
      }
    }
  }

  // --- Cleanup ---

  async onModuleDestroy(): Promise<void> {
    this.logger.log('Disconnecting Redis Pub/Sub clients');
    await this.subscriber.quit().catch(() => {});
    await this.publisher.quit().catch(() => {});
  }
}
