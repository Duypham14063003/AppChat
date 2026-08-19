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
  OdooTaskTag,
} from '../../auth/services/odoo.service.js';
import { User } from '../../auth/entities/user.entity.js';

const PROJECT_CACHE_TTL_SECONDS = 5 * 60;

const APP_TASK_STAGE_DEFS = [
  { name: 'BACKLOG', sequence: 0, aliases: ['BACKLOG', 'PRIORITIZED'] },
  {
    name: 'CODING',
    sequence: 1,
    aliases: ['CODING', 'Coding', 'DEV IN PROGRESS'],
  },
  { name: 'STAGING', sequence: 2, aliases: ['STAGING'] },
  { name: 'PRODUCTION', sequence: 3, aliases: ['PRODUCTION'] },
  { name: 'COMPLETED', sequence: 4, aliases: ['COMPLETED', 'DONE'] },
] as const;

export interface ProjectTaskStages {
  project_id: number;
  project_name: string;
  stages: OdooTaskStage[];
}

@Injectable()
export class TaskService {
  private readonly logger = new Logger(TaskService.name);
  private readonly redis: Redis;

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
    await this.redis.set(
      key,
      JSON.stringify(projects),
      'EX',
      PROJECT_CACHE_TTL_SECONDS,
    );
    return projects;
  }

  async getTaskStages(refresh = false): Promise<OdooTaskStage[]> {
    const key = 'tasks:stages:app';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as OdooTaskStage[];

    const odooStages = await this.getRawTaskStages(refresh);
    const byNormalizedName = new Map<string, OdooTaskStage>();
    for (const stage of odooStages) {
      const normalized = stage.name.trim().toUpperCase();
      if (!byNormalizedName.has(normalized)) {
        byNormalizedName.set(normalized, stage);
      }
    }

    const stages = APP_TASK_STAGE_DEFS.map((def, index) => {
      const matched = def.aliases
        .map((alias) => byNormalizedName.get(alias.trim().toUpperCase()))
        .find(Boolean);

      return {
        id: matched?.id ?? index + 1,
        name: def.name,
        sequence: def.sequence,
      };
    });

    await this.redis.set(key, JSON.stringify(stages), 'EX', 900);
    return stages;
  }

  async getProjectStages(
    projectId: number,
    refresh = false,
  ): Promise<ProjectTaskStages> {
    const [projects, stages] = await Promise.all([
      this.getAllProjects(refresh),
      this.getRawTaskStages(refresh),
    ]);

    const project = projects.find((item) => item.id === projectId);

    return {
      project_id: projectId,
      project_name: project?.name ?? `Project #${projectId}`,
      stages: this.filterStagesByProject(stages, projectId),
    };
  }

  async getAllProjectStages(refresh = false): Promise<ProjectTaskStages[]> {
    const [projects, stages] = await Promise.all([
      this.getAllProjects(refresh),
      this.getRawTaskStages(refresh),
    ]);

    return projects.map((project) => ({
      project_id: project.id,
      project_name: project.name,
      stages: this.filterStagesByProject(stages, project.id),
    }));
  }

  async getTasks(
    projectId: number,
    stageName?: string,
    stageId?: number,
    sort?: string,
    refresh = false,
    includeSubtasks = false,
  ): Promise<OdooTask[]> {
    const key = includeSubtasks
      ? 'tasks:project:' + projectId + ':with-subtasks'
      : 'tasks:project:' + projectId;
    if (refresh) await this.redis.del(key);

    let tasks: OdooTask[];
    const cached = await this.redis.get(key);
    if (cached) {
      tasks = JSON.parse(cached) as OdooTask[];
    } else {
      tasks = await this.odoo.fetchTasks(projectId, includeSubtasks);
      // Resolve user_ids (int[]) to [id, name] pairs using local DB
      tasks = await this.resolveTaskAssignees(tasks);
      await this.redis.set(key, JSON.stringify(tasks), 'EX', 300);
    }

    if (stageName) {
      tasks = tasks.filter((t) =>
        this.matchesRequestedStageName(t.stage_id, stageName),
      );
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

    const noteId = await this.odoo.writeTaskLogNote(
      taskId,
      body,
      user.odoo_uid,
    );
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

  // get tasks by user id (odoo_uid) across all projects, with optional stage filter
  async getUserTasks(
    odooUid: number,
    stageName?: string,
    stageId?: number,
    refresh = false,
  ): Promise<OdooTask[]> {
    const key = `tasks:user:${odooUid}`;
    if (refresh) await this.redis.del(key);

    let tasks: OdooTask[];
    const cached = await this.redis.get(key);
    if (cached) {
      tasks = JSON.parse(cached) as OdooTask[];
    } else {
      tasks = await this.odoo.fetchTasksByUser(odooUid);
      tasks = await this.resolveTaskAssignees(tasks);
      await this.redis.set(key, JSON.stringify(tasks), 'EX', 300);
    }

    if (stageName) {
      tasks = tasks.filter((t) =>
        this.matchesRequestedStageName(t.stage_id, stageName),
      );
    } else if (stageId) {
      tasks = tasks.filter(
        (t) => Array.isArray(t.stage_id) && t.stage_id[0] === stageId,
      );
    }

    return tasks;
  }

  async getMyTasks(
    userId: string,
    stageName?: string,
    stageId?: number,
    refresh = false,
  ): Promise<OdooTask[]> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user?.odoo_uid) {
      this.logger.warn(`getMyTasks: missing odoo_uid for userId=${userId}`);
      return [];
    }

    return this.getUserTasks(user.odoo_uid, stageName, stageId, refresh);
  }

  private matchesRequestedStageName(
    stage: OdooTask['stage_id'],
    requestedStageName: string,
  ): boolean {
    if (!Array.isArray(stage)) return false;

    const normalizedRequested = this.normalizeStageName(requestedStageName);
    const appStage = APP_TASK_STAGE_DEFS.find(
      (def) => this.normalizeStageName(def.name) === normalizedRequested,
    );
    const normalizedActual = this.normalizeStageName(stage[1]);

    if (!appStage) {
      return normalizedActual === normalizedRequested;
    }

    return appStage.aliases.some(
      (alias) => this.normalizeStageName(alias) === normalizedActual,
    );
  }

  async getTaskTags(refresh = false): Promise<OdooTaskTag[]> {
    const key = 'tasks:tags:app';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as OdooTaskTag[];

    const tags = await this.odoo.fetchProjectTags();
    await this.redis.set(key, JSON.stringify(tags), 'EX', 900);
    return tags;
  }

  private normalizeStageName(name: string): string {
    return name.trim().toUpperCase();
  }

  private async getRawTaskStages(refresh = false): Promise<OdooTaskStage[]> {
    const key = 'tasks:stages:odoo';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as OdooTaskStage[];

    const stages = await this.odoo.fetchTaskStages();
    await this.redis.set(key, JSON.stringify(stages), 'EX', 900);
    return stages;
  }

  private async getAllProjects(refresh = false): Promise<OdooProject[]> {
    const key = 'tasks:projects:all';
    if (refresh) await this.redis.del(key);

    const cached = await this.redis.get(key);
    if (cached) return JSON.parse(cached) as OdooProject[];

    const projects = await this.odoo.fetchProjects();
    await this.redis.set(key, JSON.stringify(projects), 'EX', 900);
    return projects;
  }

  private filterStagesByProject(
    stages: OdooTaskStage[],
    projectId: number,
  ): OdooTaskStage[] {
    return stages
      .filter(
        (stage) =>
          Array.isArray(stage.project_ids) &&
          stage.project_ids.includes(projectId),
      )
      .sort((a, b) => {
        if (a.sequence !== b.sequence) {
          return a.sequence - b.sequence;
        }
        return a.id - b.id;
      });
  }
}
