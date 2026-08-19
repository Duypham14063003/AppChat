import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type { WebSocket } from 'ws';

@Injectable()
export class ConnectionManager {
  private readonly connections = new Map<string, Set<WebSocket>>();
  private readonly socketToUser = new Map<WebSocket, string>();
  private readonly socketToId = new Map<WebSocket, string>();

  addConnection(userId: string, socket: WebSocket): void {
    let sockets = this.connections.get(userId);
    if (!sockets) {
      sockets = new Set();
      this.connections.set(userId, sockets);
    }
    sockets.add(socket);
    this.socketToUser.set(socket, userId);
    this.socketToId.set(socket, randomUUID());
  }

  removeConnection(socket: WebSocket): string | undefined {
    const userId = this.socketToUser.get(socket);
    if (!userId) return undefined;
    this.socketToUser.delete(socket);
    this.socketToId.delete(socket);
    const sockets = this.connections.get(userId);
    if (sockets) {
      sockets.delete(socket);
      if (sockets.size === 0) {
        this.connections.delete(userId);
      }
    }
    return userId;
  }

  getConnections(userId: string): Set<WebSocket> | undefined {
    return this.connections.get(userId);
  }

  getUserId(socket: WebSocket): string | undefined {
    return this.socketToUser.get(socket);
  }

  getSocketId(socket: WebSocket): string | undefined {
    return this.socketToId.get(socket);
  }

  isOnline(userId: string): boolean {
    const sockets = this.connections.get(userId);
    return !!sockets && sockets.size > 0;
  }

  getAllConnectedUserIds(): string[] {
    return Array.from(this.connections.keys());
  }
}
