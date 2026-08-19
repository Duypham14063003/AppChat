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
import { Subject } from 'rxjs';
import { ConversationMember } from '../entities/conversation-member.entity.js';
import { ConnectionManager } from './connection-manager.service.js';

@Injectable()
export class RedisPubSubService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisPubSubService.name);
  private publisher!: Redis;
  private subscriber!: Redis;
  private readonly channelRefCount = new Map<string, number>();
  private readonly activeChannels = new Set<string>();
  private readonly globalRewardUpdate$ = new Subject<void>();

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
    this.subscriber.on('ready', () => {
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

    this.subscriber.subscribe('rewards:global:updated').catch((err) => {
      this.logger.error(
        `Failed to subscribe to global rewards channel: ${err.message}`,
      );
    });
  }

  // --- Publish ---

  async publish(
    convId: string,
    message: Record<string, unknown>,
  ): Promise<void> {
    const channel = this.getConversationChannel(convId);
    await this.publisher.publish(channel, JSON.stringify(message));
  }

  async publishUserEvent(
    userId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const channel = this.getUserChannel(userId);
    await this.publisher.publish(channel, JSON.stringify(data));
  }

  async publishGlobalRewardUpdate(): Promise<void> {
    await this.publisher.publish(
      'rewards:global:updated',
      JSON.stringify({ timestamp: new Date().toISOString() }),
    );
  }

  onGlobalRewardUpdate() {
    return this.globalRewardUpdate$.asObservable();
  }

  async getCache(key: string): Promise<string | null> {
    return this.publisher.get(key);
  }

  async setCache(
    key: string,
    value: string,
    ttlSeconds?: number,
  ): Promise<void> {
    if (ttlSeconds) {
      await this.publisher.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.publisher.set(key, value);
    }
  }

  async setCacheIfAbsent(
    key: string,
    value: string,
    ttlSeconds: number,
  ): Promise<boolean> {
    const result = await this.publisher.set(key, value, 'EX', ttlSeconds, 'NX');
    return result === 'OK';
  }

  async deleteCache(key: string): Promise<void> {
    await this.publisher.del(key);
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
    await this.subscribe(this.getUserChannel(userId));

    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    for (const m of memberships) {
      await this.subscribe(this.getConversationChannel(m.conv_id));
    }
  }

  async unsubscribeUser(userId: string): Promise<void> {
    await this.unsubscribe(this.getUserChannel(userId));

    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    for (const m of memberships) {
      await this.unsubscribe(this.getConversationChannel(m.conv_id));
    }
  }

  async subscribeConversation(convId: string): Promise<void> {
    await this.subscribe(this.getConversationChannel(convId));
  }

  // --- Fan-out handler ---

  private handleMessage(channel: string, raw: string): void {
    if (channel === 'rewards:global:updated') {
      this.globalRewardUpdate$.next();
      return;
    }
    if (channel.startsWith('chat:user:')) {
      void this.handleUserMessage(channel, raw);
      return;
    }

    try {
      const data = JSON.parse(raw);
      const convId = channel.replace('chat:conv:', '');
      const senderId = data.sender_id as string;
      const senderSocketId = data._senderSocketId as string | undefined;

      // Remove internal field before sending to clients
      delete data._senderSocketId;

      // Find all members of this conversation who are online on this instance
      // We need to query memberRepo, but this is sync handler — use cached approach
      // Instead, iterate all connected users and check if they have connections
      this.fanOutToConversationMembers(convId, senderId, senderSocketId, data);
    } catch (err: any) {
      this.logger.error(`Failed to handle Redis message: ${err.message}`);
    }
  }

  private async handleUserMessage(channel: string, raw: string): Promise<void> {
    try {
      const data = JSON.parse(raw) as Record<string, unknown>;
      const userId = channel.replace('chat:user:', '');
      const eventName = (data._event as string) || 'user_event';
      delete data._event;

      if (eventName === 'conversation_added') {
        const convId = data.conv_id;
        if (typeof convId === 'string' && convId) {
          await this.subscribeConversation(convId);
        }
      }

      this.fanOutToUser(userId, eventName, data);
    } catch (err: any) {
      this.logger.error(`Failed to handle Redis user message: ${err.message}`);
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
      const sockets = this.connectionManager.getConnections(member.user_id);
      if (!sockets) continue;
      for (const socket of sockets) {
        const socketId = this.connectionManager.getSocketId(socket);
        const shouldSkipOriginSocket =
          senderSocketId != null &&
          socketId === senderSocketId &&
          (eventName === 'new_message' || eventName === 'typing');
        if (shouldSkipOriginSocket) {
          continue;
        }
        if (socket.readyState === 1) {
          // OPEN
          socket.send(envelope);
        }
      }
    }
  }

  private fanOutToUser(
    userId: string,
    eventName: string,
    data: Record<string, unknown>,
  ): void {
    const sockets = this.connectionManager.getConnections(userId);
    if (!sockets) return;

    const envelope = JSON.stringify({ event: eventName, data });
    for (const socket of sockets) {
      if (socket.readyState === 1) {
        socket.send(envelope);
      }
    }
  }

  private getConversationChannel(convId: string): string {
    return `chat:conv:${convId}`;
  }

  private getUserChannel(userId: string): string {
    return `chat:user:${userId}`;
  }

  // --- Cleanup ---

  async onModuleDestroy(): Promise<void> {
    this.logger.log('Disconnecting Redis Pub/Sub clients');
    await this.subscriber.quit().catch(() => {});
    await this.publisher.quit().catch(() => {});
  }
}
