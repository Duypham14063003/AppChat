import { Injectable } from '@nestjs/common';
import type { WebSocket } from 'ws';

@Injectable()
export class ConnectionManager {
  private readonly connections = new Map<string, Set<WebSocket>>();
  private readonly socketToUser = new Map<WebSocket, string>();

  addConnection(userId: string, socket: WebSocket): void {
    let sockets = this.connections.get(userId);
    if (!sockets) {
      sockets = new Set();
      this.connections.set(userId, sockets);
    }
    sockets.add(socket);
    this.socketToUser.set(socket, userId);
  }

  removeConnection(socket: WebSocket): string | undefined {
    const userId = this.socketToUser.get(socket);
    if (!userId) return undefined;
    this.socketToUser.delete(socket);
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

  isOnline(userId: string): boolean {
    const sockets = this.connections.get(userId);
    return !!sockets && sockets.size > 0;
  }

  getAllConnectedUserIds(): string[] {
    return Array.from(this.connections.keys());
  }
}
