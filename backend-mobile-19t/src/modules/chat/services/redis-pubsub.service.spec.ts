const redisInstances: any[] = [];

jest.mock('ioredis', () =>
  jest.fn().mockImplementation(() => {
    const handlers = new Map<string, (...args: any[]) => void>();
    const instance = {
      on: jest.fn((event: string, handler: (...args: any[]) => void) => {
        handlers.set(event, handler);
        return instance;
      }),
      subscribe: jest.fn().mockResolvedValue(undefined),
      unsubscribe: jest.fn().mockResolvedValue(undefined),
      publish: jest.fn().mockResolvedValue(1),
      quit: jest.fn().mockResolvedValue(undefined),
      emit: (event: string, ...args: any[]) => {
        const handler = handlers.get(event);
        if (handler) {
          handler(...args);
        }
      },
    };

    redisInstances.push(instance);
    return instance;
  }),
);

import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { RedisPubSubService } from './redis-pubsub.service';
import { ConversationMember } from '../entities/conversation-member.entity';
import { ConnectionManager } from './connection-manager.service';

describe('RedisPubSubService', () => {
  let service: RedisPubSubService;
  const memberRepo = {
    find: jest.fn(),
  };
  const connectionManager = {
    getConnections: jest.fn(),
    getSocketId: jest.fn(),
  };
  const configService = {
    get: jest.fn((key: string, fallback: unknown) => {
      if (key === 'REDIS_HOST') return 'localhost';
      if (key === 'REDIS_PORT') return 6379;
      return fallback;
    }),
  };

  beforeEach(async () => {
    redisInstances.length = 0;
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisPubSubService,
        { provide: ConfigService, useValue: configService },
        { provide: ConnectionManager, useValue: connectionManager },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: memberRepo,
        },
      ],
    }).compile();

    service = module.get(RedisPubSubService);
    service.onModuleInit();
  });

  it('subscribes and unsubscribes user-scoped plus conversation channels together', async () => {
    memberRepo.find
      .mockResolvedValueOnce([{ conv_id: 'conv-1' }, { conv_id: 'conv-2' }])
      .mockResolvedValueOnce([{ conv_id: 'conv-1' }, { conv_id: 'conv-2' }]);

    await service.subscribeUser('user-1');
    await service.unsubscribeUser('user-1');

    const subscriber = redisInstances[1];
    expect(subscriber.subscribe).toHaveBeenCalledWith('chat:user:user-1');
    expect(subscriber.subscribe).toHaveBeenCalledWith('chat:conv:conv-1');
    expect(subscriber.subscribe).toHaveBeenCalledWith('chat:conv:conv-2');
    expect(subscriber.unsubscribe).toHaveBeenCalledWith('chat:user:user-1');
    expect(subscriber.unsubscribe).toHaveBeenCalledWith('chat:conv:conv-1');
    expect(subscriber.unsubscribe).toHaveBeenCalledWith('chat:conv:conv-2');
  });

  it('fans out user-scoped membership events and subscribes the new conversation locally', async () => {
    const socket = {
      readyState: 1,
      send: jest.fn(),
    };
    memberRepo.find.mockResolvedValue([]);
    connectionManager.getConnections.mockImplementation((userId: string) =>
      userId === 'user-1' ? new Set([socket]) : undefined,
    );

    await service.subscribeUser('user-1');

    const subscriber = redisInstances[1];
    subscriber.emit(
      'message',
      'chat:user:user-1',
      JSON.stringify({
        _event: 'conversation_added',
        type: 'group_membership_added',
        conv_id: 'conv-99',
        conv_type: 'GROUP',
        conv_name: 'Backend Team',
      }),
    );

    await new Promise((resolve) => setImmediate(resolve));

    expect(subscriber.subscribe).toHaveBeenCalledWith('chat:conv:conv-99');
    expect(socket.send).toHaveBeenCalledWith(
      JSON.stringify({
        event: 'conversation_added',
        data: {
          type: 'group_membership_added',
          conv_id: 'conv-99',
          conv_type: 'GROUP',
          conv_name: 'Backend Team',
        },
      }),
    );
  });

  it('fans out new_message to sender secondary sockets and other members while skipping the origin socket only', async () => {
    const senderOriginSocket = {
      readyState: 1,
      send: jest.fn(),
    };
    const senderSecondarySocket = {
      readyState: 1,
      send: jest.fn(),
    };
    const recipientSocket = {
      readyState: 1,
      send: jest.fn(),
    };

    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'user-2' },
    ]);
    connectionManager.getConnections.mockImplementation((userId: string) => {
      if (userId === 'user-1') {
        return new Set([senderOriginSocket, senderSecondarySocket]);
      }
      if (userId === 'user-2') {
        return new Set([recipientSocket]);
      }
      return undefined;
    });
    connectionManager.getSocketId.mockImplementation((socket: unknown) => {
      if (socket === senderOriginSocket) return 'socket-origin';
      if (socket === senderSecondarySocket) return 'socket-secondary';
      if (socket === recipientSocket) return 'socket-recipient';
      return undefined;
    });

    const subscriber = redisInstances[1];
    subscriber.emit(
      'message',
      'chat:conv:conv-1',
      JSON.stringify({
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        content: 'hello',
        _senderSocketId: 'socket-origin',
      }),
    );

    await new Promise((resolve) => setImmediate(resolve));

    const expectedEnvelope = JSON.stringify({
      event: 'new_message',
      data: {
        id: 'msg-1',
        conv_id: 'conv-1',
        sender_id: 'user-1',
        content: 'hello',
      },
    });

    expect(senderOriginSocket.send).not.toHaveBeenCalled();
    expect(senderSecondarySocket.send).toHaveBeenCalledWith(expectedEnvelope);
    expect(recipientSocket.send).toHaveBeenCalledWith(expectedEnvelope);
  });

  it('continues to fan out typing events to sender secondary sockets while skipping the origin socket only', async () => {
    const senderOriginSocket = {
      readyState: 1,
      send: jest.fn(),
    };
    const senderSecondarySocket = {
      readyState: 1,
      send: jest.fn(),
    };
    const recipientSocket = {
      readyState: 1,
      send: jest.fn(),
    };

    memberRepo.find.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'user-2' },
    ]);
    connectionManager.getConnections.mockImplementation((userId: string) => {
      if (userId === 'user-1') {
        return new Set([senderOriginSocket, senderSecondarySocket]);
      }
      if (userId === 'user-2') {
        return new Set([recipientSocket]);
      }
      return undefined;
    });
    connectionManager.getSocketId.mockImplementation((socket: unknown) => {
      if (socket === senderOriginSocket) return 'socket-origin';
      if (socket === senderSecondarySocket) return 'socket-secondary';
      if (socket === recipientSocket) return 'socket-recipient';
      return undefined;
    });

    const subscriber = redisInstances[1];
    subscriber.emit(
      'message',
      'chat:conv:conv-1',
      JSON.stringify({
        conv_id: 'conv-1',
        sender_id: 'user-1',
        _event: 'typing',
        state: 'start',
        _senderSocketId: 'socket-origin',
      }),
    );

    await new Promise((resolve) => setImmediate(resolve));

    const expectedEnvelope = JSON.stringify({
      event: 'typing',
      data: {
        conv_id: 'conv-1',
        sender_id: 'user-1',
        state: 'start',
      },
    });

    expect(senderOriginSocket.send).not.toHaveBeenCalled();
    expect(senderSecondarySocket.send).toHaveBeenCalledWith(expectedEnvelope);
    expect(recipientSocket.send).toHaveBeenCalledWith(expectedEnvelope);
  });
});
