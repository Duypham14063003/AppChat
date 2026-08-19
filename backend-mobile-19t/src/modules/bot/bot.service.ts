import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../auth/entities/user.entity.js';
import { ConversationMember } from '../chat/entities/conversation-member.entity.js';
import { Conversation } from '../chat/entities/conversation.entity.js';
import { Message } from '../chat/entities/message.entity.js';
import { ChatService } from '../chat/services/chat.service.js';
import { MessageType } from '../chat/dto/chat.dto.js';
import {
  CreateBotDto,
  DeleteBotMessageDto,
  GetBotMessagesQueryDto,
  ListBotsQueryDto,
  SendBotMessageDto,
  UpdateBotDto,
  UpdateBotMessageDto,
} from './dto/bot.dto.js';

const BOT_USER_ID = '00000000-0000-0000-0000-000000000001';
const BOT_USER_EMAIL = 'bot@system.local';
const BOT_USER_NAME = 'System Bot';

@Injectable()
export class BotService {
  private readonly logger = new Logger(BotService.name);

  constructor(
    private readonly chatService: ChatService,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(Conversation)
    private readonly convRepo: Repository<Conversation>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
  ) {}

  // --- Admin operations ---

  async createBot(dto: CreateBotDto, adminUserId: string | null): Promise<User> {
    // Get next negative odoo_uid for the bot
    const odooUid = await this.getNextBotOdooUid();

    // Create bot user
    const bot = this.userRepo.create({
      odoo_uid: odooUid,
      email: dto.email,
      name: dto.name,
      avatar_url: dto.avatar_url || null,
      employment_status: 'official',
      is_active: true,
      is_bot: true,
      bot_description: dto.description || null,
      bot_created_by: adminUserId,
    });

    const savedBot = await this.userRepo.save(bot);
    this.logger.log(
      `Bot created: ${savedBot.id} (${savedBot.email}) by ${adminUserId ?? 'public-api'}`,
    );

    return savedBot;
  }

  async listBots(includeInactive: boolean = false): Promise<User[]> {
    const query = this.userRepo
      .createQueryBuilder('user')
      .where('user.is_bot = :isBot', { isBot: true });

    if (!includeInactive) {
      query.andWhere('user.is_active = :isActive', { isActive: true });
    }

    query.orderBy('user.created_at', 'DESC');

    return await query.getMany();
  }

  async getBot(botId: string): Promise<User> {
    const bot = await this.userRepo.findOne({
      where: { id: botId, is_bot: true },
    });

    if (!bot) {
      throw new NotFoundException('Bot not found');
    }

    return bot;
  }

  async updateBot(botId: string, dto: UpdateBotDto): Promise<User> {
    const bot = await this.getBot(botId);

    // Prevent updating system bot
    if (bot.id === BOT_USER_ID) {
      throw new BadRequestException('Cannot update system bot');
    }

    if (dto.name !== undefined) {
      bot.name = dto.name;
    }
    if (dto.description !== undefined) {
      bot.bot_description = dto.description;
    }
    if (dto.avatar_url !== undefined) {
      bot.avatar_url = dto.avatar_url;
    }

    const updated = await this.userRepo.save(bot);
    this.logger.log(`Bot updated: ${updated.id}`);

    return updated;
  }

  async deactivateBot(botId: string): Promise<void> {
    const bot = await this.getBot(botId);

    // Prevent deactivating system bot
    if (bot.id === BOT_USER_ID) {
      throw new BadRequestException('Cannot deactivate system bot');
    }

    await this.userRepo.update(botId, { is_active: false });
    this.logger.log(`Bot deactivated: ${botId}`);
  }

  // --- Bot messaging ---

  async sendBotMessage(dto: SendBotMessageDto) {
    // Validate exactly one of conversation_id or user_id is provided
    if (!dto.conversation_id && !dto.user_id) {
      throw new BadRequestException(
        'Must provide either conversation_id or user_id',
      );
    }
    if (dto.conversation_id && dto.user_id) {
      throw new BadRequestException(
        'Cannot provide both conversation_id and user_id',
      );
    }

    // Validate bot exists and is active
    const bot = await this.validateBotExists(dto.bot_id);

    let conversationId: string;

    if (dto.conversation_id) {
      // Send to existing conversation
      conversationId = dto.conversation_id;
    } else {
      // Send DM to user - find or create direct conversation
      conversationId = await this.findOrCreateDirectConversation(
        dto.bot_id,
        dto.user_id!,
      );
    }

    const messageId = dto.external_message_id || randomUUID();
    const message = await this.chatService.sendMessage(
      bot.id,
      {
        id: messageId,
        conv_id: conversationId,
        type: MessageType.TEXT,
        content: dto.content,
        metadata: dto.metadata,
      },
      undefined,
      true, // Bypass membership check for bots
    );

    this.logger.log(
      `Bot message sent: bot=${dto.bot_id}, conversation=${conversationId}, message=${message.id}`,
    );

    return {
      success: true,
      conversation_id: conversationId,
      message_id: message.id,
      created_at: message.created_at,
      sender: {
        id: bot.id,
        email: bot.email,
        name: bot.name,
      },
    };
  }

  async listBotConversations() {
    const conversations = await this.convRepo.find({
      where: {
        type: 'GROUP',
      },
      select: ['id', 'name'],
      order: {
        name: 'ASC',
      },
    });

    return conversations
      .filter(
        (conversation) =>
          conversation.name !== null && conversation.name !== '[Đã xóa]',
      )
      .map((conversation) => ({
        id: conversation.id,
        name: conversation.name,
      }));
  }

  async listBotUsers() {
    const users = await this.userRepo.find({
      where: {
        is_active: true,
        is_bot: false,
      },
      select: ['id', 'name'],
      order: {
        name: 'ASC',
      },
    });

    return users
      .filter((user) => user.name !== null && user.name.trim().length > 0)
      .map((user) => ({
        id: user.id,
        name: user.name,
      }));
  }

  // --- Bot message management ---

  async getBotMessages(query: GetBotMessagesQueryDto) {
    // Validate bot exists
    await this.validateBotExists(query.bot_id);

    const page = query.page || 1;
    const limit = query.limit || 20;
    const offset = (page - 1) * limit;

    // Build query
    const queryBuilder = this.messageRepo
      .createQueryBuilder('message')
      .leftJoinAndSelect('message.conversation', 'conversation')
      .where('message.sender_id = :botId', { botId: query.bot_id })
      .andWhere('message.deleted_at IS NULL');

    // Filter by conversation if provided
    if (query.conversation_id) {
      queryBuilder.andWhere('message.conv_id = :convId', {
        convId: query.conversation_id,
      });
    }

    // Get total count
    const total = await queryBuilder.getCount();

    // Get paginated messages
    const messages = await queryBuilder
      .orderBy('message.created_at', 'DESC')
      .skip(offset)
      .take(limit)
      .getMany();

    return {
      messages: messages.map((msg) => ({
        id: msg.id,
        conversation_id: msg.conv_id,
        content: msg.content,
        type: msg.type,
        metadata: msg.metadata,
        created_at: msg.created_at,
        edited_at: msg.edited_at,
      })),
      pagination: {
        page,
        limit,
        total,
        total_pages: Math.ceil(total / limit),
      },
    };
  }

  async updateBotMessage(dto: UpdateBotMessageDto) {
    // Validate bot exists and is active
    await this.validateBotExists(dto.bot_id);

    // Find message
    const message = await this.messageRepo.findOne({
      where: {
        id: dto.message_id,
        sender_id: dto.bot_id,
      },
    });

    if (!message) {
      throw new NotFoundException('Message not found or not owned by this bot');
    }

    if (message.deleted_at) {
      throw new BadRequestException('Cannot update deleted message');
    }

    // Update message
    message.content = dto.content;
    message.edited_at = new Date();

    if (dto.metadata !== undefined) {
      message.metadata = dto.metadata;
    }

    const updated = await this.messageRepo.save(message);

    this.logger.log(
      `Bot message updated: bot=${dto.bot_id}, message=${dto.message_id}`,
    );

    return {
      success: true,
      message_id: updated.id,
      content: updated.content,
      metadata: updated.metadata,
      edited_at: updated.edited_at,
    };
  }

  async deleteBotMessage(dto: DeleteBotMessageDto) {
    // Validate bot exists and is active
    await this.validateBotExists(dto.bot_id);

    // Find message
    const message = await this.messageRepo.findOne({
      where: {
        id: dto.message_id,
        sender_id: dto.bot_id,
      },
    });

    if (!message) {
      throw new NotFoundException('Message not found or not owned by this bot');
    }

    if (message.deleted_at) {
      throw new BadRequestException('Message already deleted');
    }

    // Soft delete message
    message.deleted_at = new Date();
    await this.messageRepo.save(message);

    this.logger.log(
      `Bot message deleted: bot=${dto.bot_id}, message=${dto.message_id}`,
    );

    return {
      success: true,
      message_id: message.id,
      deleted_at: message.deleted_at,
    };
  }

  // --- Legacy method (kept for backward compatibility) ---

  async sendGroupMessage(dto: SendBotMessageDto) {
    // Redirect to new method with system bot
    return this.sendBotMessage({
      ...dto,
      bot_id: BOT_USER_ID,
      conversation_id: dto.conversation_id,
    });
  }

  // --- Private helpers ---

  private async validateBotExists(botId: string): Promise<User> {
    const bot = await this.userRepo.findOne({
      where: { id: botId, is_bot: true },
    });

    if (!bot) {
      throw new NotFoundException('Bot not found');
    }

    if (!bot.is_active) {
      throw new ForbiddenException('Bot is not active');
    }

    return bot;
  }

  private async getNextBotOdooUid(): Promise<number> {
    const result = await this.userRepo
      .createQueryBuilder('user')
      .select('MIN(user.odoo_uid)', 'min')
      .where('user.odoo_uid < 0')
      .getRawOne();

    // If no negative odoo_uid exists, start with -1
    // Otherwise, decrement the minimum
    return (result?.min || 0) - 1;
  }

  private async findOrCreateDirectConversation(
    botId: string,
    userId: string,
  ): Promise<string> {
    // Check if user exists
    const targetUser = await this.userRepo.findOne({ where: { id: userId } });
    if (!targetUser) {
      throw new NotFoundException('Target user not found');
    }

    // Try to find existing DIRECT conversation between bot and user
    const existingConv = await this.convRepo
      .createQueryBuilder('conv')
      .innerJoin('conv.members', 'member1', 'member1.user_id = :botId', {
        botId,
      })
      .innerJoin('conv.members', 'member2', 'member2.user_id = :userId', {
        userId,
      })
      .where('conv.type = :type', { type: 'DIRECT' })
      .getOne();

    if (existingConv) {
      return existingConv.id;
    }

    // Create new DIRECT conversation
    const conversation = this.convRepo.create({
      type: 'DIRECT',
      name: null,
      created_by: botId,
    });

    const savedConv = await this.convRepo.save(conversation);

    // Add both bot and user as members
    await this.memberRepo.save([
      this.memberRepo.create({
        conv_id: savedConv.id,
        user_id: botId,
        role: 'member',
      }),
      this.memberRepo.create({
        conv_id: savedConv.id,
        user_id: userId,
        role: 'member',
      }),
    ]);

    this.logger.log(
      `Created direct conversation: ${savedConv.id} between bot ${botId} and user ${userId}`,
    );

    return savedConv.id;
  }

  private async ensureBotUser(): Promise<User> {
    const existingById = await this.userRepo.findOne({
      where: { id: BOT_USER_ID },
    });
    if (existingById) {
      if (
        existingById.email !== BOT_USER_EMAIL ||
        existingById.name !== BOT_USER_NAME ||
        !existingById.is_active
      ) {
        await this.userRepo.update(existingById.id, {
          email: BOT_USER_EMAIL,
          name: BOT_USER_NAME,
          is_active: true,
        });
        return (await this.userRepo.findOneByOrFail({ id: existingById.id })) as User;
      }
      return existingById;
    }

    const existingByEmail = await this.userRepo.findOne({
      where: { email: BOT_USER_EMAIL },
    });
    if (existingByEmail) {
      if (!existingByEmail.is_active || existingByEmail.odoo_uid !== 0) {
        await this.userRepo.update(existingByEmail.id, {
          odoo_uid: 0,
          name: BOT_USER_NAME,
          is_active: true,
        });
        return (await this.userRepo.findOneByOrFail({
          id: existingByEmail.id,
        })) as User;
      }
      return existingByEmail;
    }

    return this.userRepo.save(
      this.userRepo.create({
        id: BOT_USER_ID,
        odoo_uid: 0,
        email: BOT_USER_EMAIL,
        name: BOT_USER_NAME,
        employment_status: 'official',
        is_active: true,
      }),
    );
  }
}
