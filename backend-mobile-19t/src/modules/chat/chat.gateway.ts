import {
  WebSocketGateway,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Logger, Inject, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { WebSocket } from 'ws';
import type { IncomingMessage } from 'http';
import Redis from 'ioredis';
import { User } from '../auth/entities/user.entity.js';
import { ConnectionManager } from './services/connection-manager.service.js';
import { RedisPubSubService } from './services/redis-pubsub.service.js';
import { ChatService } from './services/chat.service.js';
import { CallService } from '../call/services/call.service.js';

interface WsEnvelope {
  event: string;
  data: Record<string, unknown>;
  id?: string;
}

@WebSocketGateway({ path: '/ws' })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);
  private readonly authTimeouts = new Map<WebSocket, NodeJS.Timeout>();
  private readonly heartbeatIntervals = new Map<WebSocket, NodeJS.Timeout>();
  private readonly pongTimeouts = new Map<WebSocket, NodeJS.Timeout>();
  private readonly rateLimitRedis: Redis;

  constructor(
    private readonly connectionManager: ConnectionManager,
    private readonly redisPubSub: RedisPubSubService,
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
    @Inject(forwardRef(() => CallService))
    private readonly callService: CallService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {
    this.rateLimitRedis = new Redis({
      host: this.config.get('REDIS_HOST', 'localhost'),
      port: this.config.get<number>('REDIS_PORT', 6379),
    });
  }

  // --- Connection handling ---

  handleConnection(socket: WebSocket, _req: IncomingMessage): void {
    // Start 5-second auth timeout
    const timeout = setTimeout(() => {
      this.sendEvent(socket, 'auth_error', { message: 'Auth timeout' });
      socket.close(4001, 'Auth timeout');
    }, 5000);
    this.authTimeouts.set(socket, timeout);

    socket.on('message', (raw: Buffer | string) => {
      this.handleRawMessage(socket, raw);
    });

    socket.on('pong', () => {
      const pongTimeout = this.pongTimeouts.get(socket);
      if (pongTimeout) {
        clearTimeout(pongTimeout);
        this.pongTimeouts.delete(socket);
      }
    });
  }

  handleDisconnect(socket: WebSocket): void {
    // Clear auth timeout
    const authTimeout = this.authTimeouts.get(socket);
    if (authTimeout) {
      clearTimeout(authTimeout);
      this.authTimeouts.delete(socket);
    }
    // Clear heartbeat
    const hbInterval = this.heartbeatIntervals.get(socket);
    if (hbInterval) {
      clearInterval(hbInterval);
      this.heartbeatIntervals.delete(socket);
    }
    const pongTimeout = this.pongTimeouts.get(socket);
    if (pongTimeout) {
      clearTimeout(pongTimeout);
      this.pongTimeouts.delete(socket);
    }
    // Remove from connection manager and unsubscribe if last connection
    const userId = this.connectionManager.removeConnection(socket);
    if (userId && !this.connectionManager.isOnline(userId)) {
      // End any active calls for this user
      this.callService.handleUserDisconnect(userId).catch((err) => {
        this.logger.error(
          `Failed to handle call cleanup for disconnected user ${userId}: ${err.message}`,
        );
      });

      // Update last_seen_at on final disconnect
      this.userRepo
        .update(userId, { last_seen_at: new Date() })
        .catch((err) => {
          this.logger.error(
            `Failed to update last_seen_at for user ${userId}: ${err.message}`,
          );
        });
      this.redisPubSub.unsubscribeUser(userId).catch((err) => {
        this.logger.error(
          `Failed to unsubscribe user ${userId}: ${err.message}`,
        );
      });
    }
  }

  // --- Message routing ---

  private async handleRawMessage(
    socket: WebSocket,
    raw: Buffer | string,
  ): Promise<void> {
    let envelope: WsEnvelope;
    try {
      envelope = JSON.parse(typeof raw === 'string' ? raw : raw.toString());
    } catch {
      this.sendEvent(socket, 'error', {
        code: 'INVALID_JSON',
        message: 'Invalid JSON',
      });
      return;
    }

    if (!envelope.event || typeof envelope.event !== 'string') {
      this.sendEvent(socket, 'error', {
        code: 'INVALID_FORMAT',
        message: 'Missing event field',
      });
      return;
    }

    // Auth must be first message
    if (envelope.event === 'auth') {
      await this.handleAuth(socket, envelope);
      return;
    }

    // Application-level ping/pong (keepalive from mobile client)
    if (envelope.event === 'ping') {
      this.sendEvent(socket, 'pong', {});
      return;
    }

    // All other events require authentication
    const userId = this.connectionManager.getUserId(socket);
    if (!userId) {
      this.sendEvent(socket, 'auth_error', { message: 'Not authenticated' });
      socket.close(4001, 'Not authenticated');
      return;
    }

    // Typing events bypass rate limiting (D5: client already throttles)
    if (envelope.event === 'typing') {
      await this.handleTyping(socket, userId, envelope);
      return;
    }

    // Rate limiting
    const allowed = await this.checkRateLimit(userId);
    if (!allowed) {
      this.sendEvent(
        socket,
        'error',
        { code: 'RATE_LIMITED', message: 'Too many messages' },
        envelope.id,
      );
      return;
    }

    switch (envelope.event) {
      case 'send_message':
        await this.handleSendMessage(socket, userId, envelope);
        break;
      case 'edit_message':
        await this.handleEditMessage(socket, userId, envelope);
        break;
      case 'recall_message':
        await this.handleRecallMessage(socket, userId, envelope);
        break;
      case 'mark_read':
        await this.handleMarkRead(userId, envelope);
        break;
      case 'mark_delivered':
        await this.handleMarkDelivered(userId, envelope);
        break;
      case 'sync':
        await this.handleSync(socket, userId, envelope);
        break;
      case 'toggle_reaction':
        await this.handleToggleReaction(socket, userId, envelope);
        break;
      case 'forward_message':
        await this.handleForwardMessage(socket, userId, envelope);
        break;
      default:
        this.sendEvent(
          socket,
          'error',
          {
            code: 'UNKNOWN_EVENT',
            message: `Unknown event: ${envelope.event}`,
          },
          envelope.id,
        );
    }
  }

  // --- Auth handler ---

  private async handleAuth(
    socket: WebSocket,
    envelope: WsEnvelope,
  ): Promise<void> {
    const authTimeout = this.authTimeouts.get(socket);
    if (authTimeout) {
      clearTimeout(authTimeout);
      this.authTimeouts.delete(socket);
    }

    const token = envelope.data?.token as string;
    if (!token) {
      this.sendEvent(socket, 'auth_error', { message: 'Missing token' });
      socket.close(4001, 'Missing token');
      return;
    }

    try {
      const payload = this.jwtService.verify(token, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });
      const userId = payload.sub as string;
      const wasOnline = this.connectionManager.isOnline(userId);

      this.connectionManager.addConnection(userId, socket);
      this.startHeartbeat(socket);

      // Update last_seen_at
      this.userRepo
        .update(userId, { last_seen_at: new Date() })
        .catch((err) => {
          this.logger.error(
            `Failed to update last_seen_at for user ${userId}: ${err.message}`,
          );
        });

      // Subscribe only when this is the first live socket for the user.
      if (!wasOnline) {
        await this.redisPubSub.subscribeUser(userId);
      }

      this.sendEvent(socket, 'auth_success', { userId });
      this.logger.log(`User ${userId} authenticated via WebSocket`);
    } catch {
      this.sendEvent(socket, 'auth_error', { message: 'Invalid token' });
      socket.close(4001, 'Invalid token');
    }
  }

  // --- Event handlers ---

  private async handleSendMessage(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    try {
      const message = await this.chatService.sendMessage(
        userId,
        envelope.data,
        socket,
      );
      this.sendEvent(
        socket,
        'message_ack',
        {
          id: message.id,
          status: 'sent',
          created_at: message.created_at,
        },
        envelope.id,
      );
    } catch (err: any) {
      this.sendEvent(
        socket,
        'error',
        {
          code: err.code || 'SEND_FAILED',
          message: err.message,
        },
        envelope.id,
      );
    }
  }

  private async handleEditMessage(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    const messageId = envelope.data.message_id as string;
    const content = envelope.data.content as string | undefined;
    const metadata = envelope.data.metadata as
      | Record<string, unknown>
      | undefined;

    if (!messageId || (!content && !metadata?.encrypted_content)) {
      this.sendEvent(
        socket,
        'error',
        { code: 'INVALID_FORMAT', message: 'Missing required fields' },
        envelope.id,
      );
      return;
    }

    try {
      const message = await this.chatService.editMessage(
        userId,
        messageId,
        content,
        metadata,
        envelope.data.blind_index_v1 as Record<string, unknown> | undefined,
      );
      this.sendEvent(
        socket,
        'message_edited',
        {
          message_id: message.id,
          content: message.content,
          metadata: message.metadata,
          edited_at: message.edited_at,
        },
        envelope.id,
      );
    } catch (err: any) {
      this.sendEvent(
        socket,
        'error',
        {
          code: err.code || 'EDIT_FAILED',
          message: err.message,
        },
        envelope.id,
      );
    }
  }

  private async handleRecallMessage(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    const messageId = envelope.data.message_id as string;
    const reason = envelope.data.reason as string | undefined;

    if (!messageId) {
      this.sendEvent(
        socket,
        'error',
        { code: 'INVALID_FORMAT', message: 'Missing required fields' },
        envelope.id,
      );
      return;
    }

    try {
      const message = await this.chatService.recallMessage(
        userId,
        messageId,
        reason,
      );
      this.sendEvent(
        socket,
        'message_recalled',
        {
          message_id: message.id,
          deleted_at: message.deleted_at,
        },
        envelope.id,
      );
    } catch (err: any) {
      this.sendEvent(
        socket,
        'error',
        {
          code: err.code || 'RECALL_FAILED',
          message: err.message,
        },
        envelope.id,
      );
    }
  }

  private async handleMarkRead(
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    try {
      await this.chatService.markRead(userId, envelope.data);
    } catch (err: any) {
      this.logger.error(`mark_read failed for user ${userId}: ${err.message}`);
    }
  }

  private async handleMarkDelivered(
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    try {
      await this.chatService.markDelivered(userId, envelope.data);
    } catch (err: any) {
      this.logger.error(
        `mark_delivered failed for user ${userId}: ${err.message}`,
      );
    }
  }

  private async handleSync(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    try {
      const lastSyncedAt = envelope.data.last_synced_at as string;
      const messages = await this.chatService.syncMessages(
        userId,
        lastSyncedAt,
      );
      this.sendEvent(socket, 'sync_response', { messages }, envelope.id);
    } catch (err: any) {
      this.logger.error(`sync failed for user ${userId}: ${err.message}`);
    }
  }

  private async handleToggleReaction(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    const messageId = envelope.data.message_id as string;
    const convId = envelope.data.conv_id as string;
    const emoji = envelope.data.emoji as string;

    if (!messageId || !convId || !emoji) {
      this.sendEvent(
        socket,
        'error',
        { code: 'INVALID_FORMAT', message: 'Missing required fields' },
        envelope.id,
      );
      return;
    }

    if (emoji.length > 10) {
      this.sendEvent(
        socket,
        'error',
        { code: 'INVALID_FORMAT', message: 'Emoji too long' },
        envelope.id,
      );
      return;
    }

    try {
      const { action, reactions } = await this.chatService.toggleReaction(
        userId,
        messageId,
        convId,
        emoji,
      );

      // Get user name for broadcast
      const user = await this.userRepo.findOne({
        where: { id: userId },
        select: ['id', 'name'],
      });

      // Ack to sender
      this.sendEvent(
        socket,
        'reaction_ack',
        { message_id: messageId, conv_id: convId, emoji, action, reactions },
        envelope.id,
      );

      // Broadcast to all conversation members via Redis PubSub
      const updatePayload = {
        message_id: messageId,
        conv_id: convId,
        user_id: userId,
        user_name: user?.name ?? 'Unknown',
        emoji,
        action,
        reactions,
        _event: 'reaction_update',
      };
      await this.redisPubSub.publish(convId, updatePayload);
    } catch (err: any) {
      this.sendEvent(
        socket,
        'error',
        { code: err.code || 'REACTION_FAILED', message: err.message },
        envelope.id,
      );
    }
  }

  // --- Heartbeat ---

  private async handleForwardMessage(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    try {
      const result = await this.chatService.forwardMessages(
        userId,
        envelope.data,
      );
      this.sendEvent(socket, 'forward_ack', result, envelope.id);
    } catch (err: any) {
      this.sendEvent(
        socket,
        'error',
        { code: err.code || 'FORWARD_FAILED', message: err.message },
        envelope.id,
      );
    }
  }

  // --- Heartbeat (typing) ---

  private async handleTyping(
    socket: WebSocket,
    userId: string,
    envelope: WsEnvelope,
  ): Promise<void> {
    const convId = envelope.data?.conv_id as string;
    if (!convId) return;

    try {
      await this.redisPubSub.publish(convId, {
        _event: 'typing',
        _senderSocketId: this.connectionManager.getSocketId(socket),
        sender_id: userId,
        user_id: userId,
        conv_id: convId,
        timestamp: Date.now(),
      });
    } catch (err: any) {
      this.logger.error(
        `typing publish failed for user ${userId}: ${err.message}`,
      );
    }
  }

  private startHeartbeat(socket: WebSocket): void {
    const interval = setInterval(() => {
      if (socket.readyState !== 1) {
        // OPEN
        clearInterval(interval);
        return;
      }
      socket.ping();
      const pongTimeout = setTimeout(() => {
        this.logger.warn('Connection dead — no pong received');
        socket.terminate();
      }, 10000);
      this.pongTimeouts.set(socket, pongTimeout);
    }, 30000);
    this.heartbeatIntervals.set(socket, interval);
  }

  // --- Rate limiting ---

  private async checkRateLimit(userId: string): Promise<boolean> {
    const key = `chat:rate:${userId}`;
    const count = await this.rateLimitRedis.incr(key);
    if (count === 1) {
      await this.rateLimitRedis.expire(key, 60);
    }
    return count <= 30;
  }

  // --- Utility ---

  sendEvent(
    socket: WebSocket,
    event: string,
    data: Record<string, unknown>,
    id?: string,
  ): void {
    if (socket.readyState !== 1) return;
    const envelope: WsEnvelope = { event, data };
    if (id) envelope.id = id;
    socket.send(JSON.stringify(envelope));
  }
}
