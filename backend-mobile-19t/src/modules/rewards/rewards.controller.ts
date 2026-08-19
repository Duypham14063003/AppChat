import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Sse,
  MessageEvent,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Observable, from, map, switchMap, throttleTime, startWith } from 'rxjs';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Public } from '../auth/decorators/public.decorator.js';
import { RewardsService } from './rewards.service.js';
import { RedisPubSubService } from '../chat/services/redis-pubsub.service.js';
import {
  CreateRedemptionDto,
  MonthlyLeaderboardQueryDto,
  RedemptionListQueryDto,
  RewardCatalogQueryDto,
  RewardsHistoryQueryDto,
  RewardsOverviewQueryDto,
  YearlyLeaderboardQueryDto,
} from './dto/rewards.dto.js';

@ApiTags('Rewards')
@ApiBearerAuth()
@Controller('rewards')
export class RewardsController {
  constructor(
    private readonly rewardsService: RewardsService,
    private readonly redisPubSubService: RedisPubSubService,
  ) { }

  @Get('wallet')
  @ApiOperation({ summary: 'Get current user reward wallet' })
  async getWallet(@CurrentUser('userId') userId: string) {
    return this.rewardsService.getMyWallet(userId);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Get current user point transaction history' })
  async getTransactions(
    @CurrentUser('userId') userId: string,
    @Query() query: RewardsHistoryQueryDto,
  ) {
    return this.rewardsService.getMyTransactions(userId, query.limit ?? 50);
  }

  @Get('catalog')
  @ApiOperation({ summary: 'Get active reward catalog' })
  async getCatalog(@Query() query: RewardCatalogQueryDto) {
    return this.rewardsService.listRewardItems(query, false);
  }

  @Public()
  @Get('overview')
  @ApiOperation({ summary: 'Get employee points leaderboard overview (Monthly)' })
  async getOverview(@Query() query: RewardsOverviewQueryDto) {
    return this.rewardsService.getOverview(query.limit ?? 20, query.department);
  }

  @Public()
  @Sse('overview/stream')
  @ApiOperation({ summary: 'Stream employee points leaderboard overview (SSE)' })
  overviewStream(@Query() query: RewardsOverviewQueryDto): Observable<MessageEvent> {
    return this.redisPubSubService.onGlobalRewardUpdate().pipe(
      startWith(null), // Trigger initial data immediately
      throttleTime(2000, undefined, { leading: true, trailing: true }), // Avoid DDOS/spamming
      switchMap(() =>
        from(this.rewardsService.getOverview(query.limit ?? 20, query.department)),
      ),
      map((data) => ({ data } as MessageEvent)),
    );
  }

  @Public()
  @Get('monthly-leaderboard')
  @ApiOperation({ summary: 'Get employee points leaderboard for a monthly cycle' })
  async getMonthlyLeaderboard(@Query() query: MonthlyLeaderboardQueryDto) {
    return this.rewardsService.getMonthlyLeaderboard(
      query.year,
      query.month,
      query.limit ?? 20,
    );
  }

  @Public()
  @Get('top-period')
  @ApiOperation({ summary: 'Get top users from point_period_history for a given period (default: active period)' })
  async getTopPeriod(
    @Query('period') period?: string,
    @Query('limit') limit?: number,
  ) {
    return this.rewardsService.getTopPeriod(period, limit ?? 3);
  }

  @Public()
  @Get('yearly-leaderboard')
  @ApiOperation({ summary: 'Get employee points leaderboard for the year' })
  async getYearlyLeaderboard(@Query() query: YearlyLeaderboardQueryDto) {
    return this.rewardsService.getYearlyLeaderboard(
      query.year,
      query.limit ?? 20,
    );
  }

  @Post('redemptions')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Redeem a reward item using points' })
  async redeem(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateRedemptionDto,
  ) {
    return this.rewardsService.redeemReward(userId, dto);
  }

  @Get('redemptions')
  @ApiOperation({ summary: 'Get current user redemption history' })
  async getMyRedemptions(
    @CurrentUser('userId') userId: string,
    @Query() query: RedemptionListQueryDto,
  ) {
    return this.rewardsService.listMyRedemptions(userId, query);
  }

  @Public()
  @Post('odoo-tasks/process')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Manually trigger Odoo task reward processing (Public - No Auth)',
  })
  async processOdooTasks() {
    await this.rewardsService.processOdooTaskRewards();
    return { message: 'Odoo task reward processing completed' };
  }
}
