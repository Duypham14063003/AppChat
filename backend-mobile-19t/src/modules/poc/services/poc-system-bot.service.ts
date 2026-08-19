import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { POC_SYSTEM_BOT_ID } from '../poc.constants.js';

@Injectable()
export class PocSystemBotService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async ensure(): Promise<string> {
    let bot = await this.userRepo.findOne({ where: { id: POC_SYSTEM_BOT_ID } });
    if (!bot) {
      bot = await this.userRepo.findOne({
        where: { email: 'bot@system.local' },
      });
    }
    if (!bot) {
      bot = await this.userRepo.save(
        this.userRepo.create({
          id: POC_SYSTEM_BOT_ID,
          odoo_uid: 0,
          email: 'bot@system.local',
          name: 'System Bot',
          employment_status: 'official',
          is_active: true,
          is_bot: true,
        }),
      );
    } else if (!bot.is_active || !bot.is_bot) {
      await this.userRepo.update(bot.id, { is_active: true, is_bot: true });
    }
    return bot.id;
  }
}
