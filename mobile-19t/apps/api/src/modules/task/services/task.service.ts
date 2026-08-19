import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Redis from 'ioredis';
import {
  OdooService,
  OdooProject,
  OdooTask,
  OdooTaskStage,
  OdooLogNote,
} from '../../auth/services/odoo.service.js';
import { User } from '../../auth/entities/user.entity.js';

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);
  private readonly redis: Redis;
  private static readonly stageAliases: Record<string, string[]> = {
    BACKLOG: ['BACKLOG', 'PRIORITIZED'],
    CODING: ['CODING', 'Coding', 'DEV IN PROGRESS'],
    STAGING: ['STAGING'],
    PRODUCTION: ['PRODUCTION'],
    COMPLETED: ['COMPLETED', 'DONE'],
  };

  constructor(
    private readonly odoo: OdooService,
    private readonly config: ConfigService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {
    this.redis = new Redis({
      host: this.config.get('REDIS_HOST', 'localhost'),
      port: this.config.get<number>('REDIS_PORT', 6379),
    });
  }

  async getProjects(userId: string, refresh = false): Promise<OdooProject[]> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    const odooUid = user?.odoo_uid;
    this.logger.log(`getProjects: userId=${userId}, odooUid=${odooUid}`);

    const key = odooUid ? `tasks:projects:${odooUid}` : 'tasks:projects';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) {
      this.logger.log(`getProjects: cache HIT key=${key}`);
      return JSON.parse(cached) as OdooProject[];
    }

    this.logger.log(`getProjects: cache MISS, fetching from Odoo`);
    const projects = await this.odoo.fetchProjects(odooUid);
    this.logger.log(`getProjects: fetched ${projects.length} projects`);
    await this.redis.set(key, JSON.stringify(projects), 'EX', 900);
    return projects;
  }

  async getTaskStages(refresh = false): Promise<OdooTaskStage[]> {
    const key = 'tasks:stages';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as OdooTaskStage[];

    const stages = await this.odoo.fetchTaskStages();
    await this.redis.set(key, JSON.stringify(stages), 'EX', 900);
    return stages;
  }

  async getTasks(
    projectId: number,
    stageId?: number,
    stageName?: string,
    sort?: string,
    refresh = false,
  ): Promise<OdooTask[]> {
    const key = `tasks:project:${projectId}`;
    if (refresh) await this.redis.del(key);

    let tasks: OdooTask[];
    const cached = await this.redis.get(key);
    if (cached) {
      tasks = JSON.parse(cached) as OdooTask[];
    } else {
      tasks = await this.odoo.fetchTasks(projectId);
      // Resolve user_ids (int[]) to [id, name] pairs using local DB
      tasks = await this.resolveTaskAssignees(tasks);
      await this.redis.set(key, JSON.stringify(tasks), 'EX', 300);
    }

    if (stageName) {
      tasks = this.filterByStageName(tasks, stageName);
    } else if (stageId) {
      tasks = tasks.filter(
        (t) => Array.isArray(t.stage_id) && t.stage_id[0] === stageId,
      );
    }

    if (sort === 'deadline') {
      tasks.sort((a, b) => {
        if (!a.date_deadline) return 1;
        if (!b.date_deadline) return -1;
        return a.date_deadline.localeCompare(b.date_deadline);
      });
    } else if (sort === 'priority') {
      tasks.sort(
        (a, b) => parseInt(b.priority || '0') - parseInt(a.priority || '0'),
      );
    } else if (sort === 'assignee') {
      tasks.sort((a, b) => {
        const nameA = a.user_ids?.[0]?.[1] || '';
        const nameB = b.user_ids?.[0]?.[1] || '';
        return nameA.localeCompare(nameB);
      });
    }

    return tasks;
  }

  async getMyTasks(
    userId: string,
    stageId?: number,
    stageName?: string,
    sort?: string,
    refresh = false,
  ): Promise<OdooTask[]> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    const odooUid = user?.odoo_uid;
    if (!odooUid) return [];

    const key = `tasks:user:${odooUid}`;
    if (refresh) await this.redis.del(key);

    let tasks: OdooTask[];
    const cached = await this.redis.get(key);
    if (cached) {
      tasks = JSON.parse(cached) as OdooTask[];
    } else {
      tasks = await this.odoo.fetchTasksForUser(odooUid);
      tasks = await this.resolveTaskAssignees(tasks);
      await this.redis.set(key, JSON.stringify(tasks), 'EX', 300);
    }

    if (stageName) {
      tasks = this.filterByStageName(tasks, stageName);
    } else if (stageId) {
      tasks = tasks.filter(
        (t) => Array.isArray(t.stage_id) && t.stage_id[0] === stageId,
      );
    }

    if (sort === 'deadline') {
      tasks.sort((a, b) => {
        if (!a.date_deadline) return 1;
        if (!b.date_deadline) return -1;
        return a.date_deadline.localeCompare(b.date_deadline);
      });
    } else if (sort === 'priority') {
      tasks.sort(
        (a, b) => parseInt(b.priority || '0') - parseInt(a.priority || '0'),
      );
    } else if (sort === 'assignee') {
      tasks.sort((a, b) => {
        const nameA = a.user_ids?.[0]?.[1] || '';
        const nameB = b.user_ids?.[0]?.[1] || '';
        return nameA.localeCompare(nameB);
      });
    }

    return tasks;
  }

  async getTaskDetail(taskId: number): Promise<OdooTask | null> {
    return this.odoo.fetchTaskById(taskId);
  }

  async getSubtasks(parentId: number): Promise<OdooTask[]> {
    const tasks = await this.odoo.fetchSubtasks(parentId);
    return this.resolveTaskAssignees(tasks);
  }

  async getLogNotes(taskId: number): Promise<OdooLogNote[]> {
    return this.odoo.fetchTaskLogNotes(taskId);
  }

  async createLogNote(
    taskId: number,
    body: string,
    userId: string,
  ): Promise<{ id: number }> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new Error('User not found');

    const noteId = await this.odoo.writeTaskLogNote(taskId, body, user.odoo_uid);
    return { id: noteId };
  }

  private async resolveTaskAssignees(tasks: OdooTask[]): Promise<OdooTask[]> {
    // Collect all unique odoo user IDs from tasks
    const odooUids = new Set<number>();
    for (const t of tasks) {
      if (Array.isArray(t.user_ids)) {
        for (const uid of t.user_ids) {
          if (typeof uid === 'number') odooUids.add(uid);
        }
      }
    }
    if (odooUids.size === 0) return tasks;

    // Lookup names from local users table
    const users = await this.userRepo.find();
    const nameMap = new Map<number, string>();
    for (const u of users) {
      nameMap.set(u.odoo_uid, u.name);
    }

    // Transform user_ids from [id, ...] to [[id, name], ...]
    return tasks.map((t) => ({
      ...t,
      user_ids: Array.isArray(t.user_ids)
        ? (t.user_ids as unknown[]).map((uid) => {
            if (typeof uid === 'number') {
              return [uid, nameMap.get(uid) || `User #${uid}`];
            }
            return uid;
          })
        : t.user_ids,
    })) as OdooTask[];
  }

  private filterByStageName(tasks: OdooTask[], stageName: string): OdooTask[] {
    const aliases = TaskService.stageAliases[stageName.toUpperCase()];
    if (!aliases || aliases.length === 0) return tasks;

    return tasks.filter((task) => {
      const rawStageName = Array.isArray(task.stage_id) ? task.stage_id[1] : null;
      if (!rawStageName) return false;
      return aliases.includes(rawStageName);
    });
  }
}
