import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, MoreThan, Repository } from 'typeorm';
import { UserSession } from '../entities/user-session.entity.js';

@Injectable()
export class SessionService {
  constructor(
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
  ) {}

  async createSession(data: {
    id?: string;
    user_id: string;
    device_id?: string;
    device_name?: string;
    refresh_token_hash: string;
    last_ip?: string;
    expires_at: Date;
  }): Promise<UserSession> {
    const session = this.sessionRepo.create(data);
    return this.sessionRepo.save(session);
  }

  async findSessionsByUser(userId: string): Promise<UserSession[]> {
    return this.sessionRepo.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
    });
  }

  async findAllActiveSessions(): Promise<UserSession[]> {
    return this.sessionRepo.find({
      where: { expires_at: MoreThan(new Date()) },
    });
  }

  async findSessionById(id: string): Promise<UserSession | null> {
    return this.sessionRepo.findOne({ where: { id } });
  }

  async findSessionByUserAndDevice(
    userId: string,
    deviceId: string,
  ): Promise<UserSession | null> {
    return this.sessionRepo.findOne({
      where: { user_id: userId, device_id: deviceId },
    });
  }

  async updateSession(id: string, data: Partial<UserSession>): Promise<void> {
    await this.sessionRepo.update(id, data);
  }

  async deleteSession(id: string): Promise<void> {
    await this.sessionRepo.delete(id);
  }

  async deleteAllSessions(userId: string): Promise<void> {
    await this.sessionRepo.delete({ user_id: userId });
  }

  async deleteExpiredSessions(): Promise<number> {
    const result = await this.sessionRepo.delete({
      expires_at: LessThan(new Date()),
    });
    return result.affected || 0;
  }
}
