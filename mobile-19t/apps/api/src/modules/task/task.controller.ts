import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { TaskService } from './services/task.service.js';

@Controller('tasks')
export class TaskController {
  constructor(private readonly taskService: TaskService) {}

  @Get('projects')
  getProjects(@CurrentUser('userId') userId: string) {
    return this.taskService.getProjects(userId);
  }

  @Get('projects/:projectId/tasks')
  getTasks(
    @Param('projectId', ParseIntPipe) projectId: number,
    @Query('stage_id') stageId?: string,
    @Query('stage_name') stageName?: string,
    @Query('sort') sort?: string,
    @Query('refresh') refresh?: string,
  ) {
    return this.taskService.getTasks(
      projectId,
      stageId ? parseInt(stageId, 10) : undefined,
      stageName,
      sort,
      refresh === 'true',
    );
  }

  @Get('stages')
  getStages() {
    return this.taskService.getTaskStages();
  }

  @Get('me')
  getMyTasks(
    @CurrentUser('userId') userId: string,
    @Query('stage_id') stageId?: string,
    @Query('stage_name') stageName?: string,
    @Query('sort') sort?: string,
    @Query('refresh') refresh?: string,
  ) {
    return this.taskService.getMyTasks(
      userId,
      stageId ? parseInt(stageId, 10) : undefined,
      stageName,
      sort,
      refresh === 'true',
    );
  }

  @Get(':taskId/subtasks')
  getSubtasks(@Param('taskId', ParseIntPipe) taskId: number) {
    return this.taskService.getSubtasks(taskId);
  }

  @Get(':taskId/log-notes')
  getLogNotes(@Param('taskId', ParseIntPipe) taskId: number) {
    return this.taskService.getLogNotes(taskId);
  }

  @Get(':taskId')
  getTaskDetail(@Param('taskId', ParseIntPipe) taskId: number) {
    return this.taskService.getTaskDetail(taskId);
  }

  @Post(':taskId/log-notes')
  @HttpCode(HttpStatus.CREATED)
  createLogNote(
    @Param('taskId', ParseIntPipe) taskId: number,
    @Body('body') body: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.taskService.createLogNote(taskId, body, userId);
  }
}
