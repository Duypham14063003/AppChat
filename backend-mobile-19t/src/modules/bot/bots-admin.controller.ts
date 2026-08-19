import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../auth/decorators/public.decorator.js';
import { BotService } from './bot.service.js';
import {
  CreateBotDto,
  ListBotsQueryDto,
  UpdateBotDto,
} from './dto/bot.dto.js';

@ApiTags('Bot Administration')
@Public()
@Controller('bots')
export class BotsAdminController {
  constructor(private readonly botService: BotService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new bot (public endpoint)' })
  async createBot(@Body() dto: CreateBotDto) {
    return await this.botService.createBot(dto, null);
  }

  @Get()
  @ApiOperation({ summary: 'List all bots (public endpoint)' })
  async listBots(@Query() query: ListBotsQueryDto) {
    const bots = await this.botService.listBots(query.include_inactive);
    return { bots };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get bot details (public endpoint)' })
  async getBot(@Param('id') id: string) {
    return await this.botService.getBot(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update bot information (public endpoint)' })
  async updateBot(@Param('id') id: string, @Body() dto: UpdateBotDto) {
    return await this.botService.updateBot(id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  @ApiOperation({ summary: 'Deactivate a bot (public endpoint)' })
  async deactivateBot(@Param('id') id: string) {
    await this.botService.deactivateBot(id);
  }
}
