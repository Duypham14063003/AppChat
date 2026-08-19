import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

export interface OdooUserInfo {
  uid: number;
  name: string;
  email: string;
}

export interface OdooEmployee {
  id: number;
  name: string;
  work_email: string | false;
  work_phone: string | false;
  department_id: [number, string] | false;
  job_title: string | false;
  user_id: [number, string] | false;
}

export interface OdooAttendanceRecord {
  id: number;
  employee_id: [number, string] | false;
  check_in: string;
  check_out: string | false;
  worked_hours?: number | false;
}

export interface OdooProject {
  id: number;
  name: string;
  user_id: [number, string] | false;
  date_start: string | false;
  date: string | false;
  task_count: number;
}

export interface OdooTask {
  id: number;
  name: string;
  user_ids: [number, string][];
  project_id?: [number, string] | false;
  stage_id: [number, string] | false;
  tag_ids: number[];
  date_deadline: string | false;
  priority: string;
  description: string | false;
  parent_id: [number, string] | false;
  child_ids: number[];
  subtask_count: number;
}

export interface OdooTaskTag {
  id: number;
  name: string;
}

export interface OdooTaskStage {
  id: number;
  name: string;
  sequence: number;
  project_ids?: number[];
}

export type OdooTaskStageAdvanceDecision =
  | { status: 'advance'; nextStage: OdooTaskStage }
  | { status: 'terminal_stage' | 'unresolved_pipeline' };

export interface OdooLogNote {
  id: number;
  body: string;
  author_id: [number, string] | false;
  date: string;
  message_type: string;
}

@Injectable()
export class OdooService {
  private readonly logger = new Logger(OdooService.name);
  private readonly odooUrl: string;
  private readonly odooDb: string;
  private readonly attendanceTimezoneOffsetMs = 7 * 60 * 60 * 1000;
  private serviceUid: number | null = null;

  constructor(private readonly config: ConfigService) {
    this.odooUrl = this.config.get<string>('ODOO_URL', 'https://erp.19t.vn');
    this.odooDb = this.config.get<string>('ODOO_DB', '19t');
  }

  /** Returns the credential for execute_kw: API key if set, otherwise service password */
  private getServiceCredential(): string {
    return (
      this.config.get<string>('ODOO_SERVICE_PASSWORD', '') ||
      this.config.get<string>('ODOO_API_KEY', '')
    );
  }

  async authenticate(email: string, password: string): Promise<OdooUserInfo> {
    try {
      const response = await axios.post(
        `${this.odooUrl}/web/session/authenticate`,
        {
          jsonrpc: '2.0',
          params: {
            db: this.odooDb,
            login: email,
            password,
          },
        },
        { timeout: 10_000 },
      );

      const result = response.data?.result;
      if (!result || !result.uid || result.uid === false) {
        throw new UnauthorizedException('Email hoặc mật khẩu không đúng');
      }

      return {
        uid: result.uid,
        name: result.name || result.username || email,
        email,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;

      if (axios.isAxiosError(error) && error.code === 'ECONNABORTED') {
        this.logger.error(`Odoo timeout: ${error.message}`);
        throw new ServiceUnavailableException(
          'Không thể kết nối hệ thống, vui lòng thử lại',
        );
      }

      if (axios.isAxiosError(error) && !error.response) {
        this.logger.error(`Odoo unreachable: ${error.message}`);
        throw new ServiceUnavailableException(
          'Không thể kết nối hệ thống, vui lòng thử lại',
        );
      }

      this.logger.error(`Odoo auth error: ${error}`);
      throw new ServiceUnavailableException(
        'Không thể kết nối hệ thống, vui lòng thử lại',
      );
    }
  }

  private async authenticateServiceAccount(): Promise<number> {
    if (this.serviceUid) return this.serviceUid;

    const username = this.config.get<string>('ODOO_SERVICE_USERNAME', '');
    const password = this.config.get<string>('ODOO_SERVICE_PASSWORD', '');
    if (!username || !password) {
      this.logger.warn('Odoo service account credentials not configured');
      return 0;
    }

    const response = await axios.post(
      `${this.odooUrl}/web/session/authenticate`,
      {
        jsonrpc: '2.0',
        params: { db: this.odooDb, login: username, password },
      },
      { timeout: 10_000 },
    );

    const result = response.data?.result;
    if (!result?.uid || result.uid === false) {
      throw new ServiceUnavailableException('Odoo service account auth failed');
    }

    this.serviceUid = result.uid as number;
    return this.serviceUid;
  }

  async fetchEmployees(): Promise<OdooEmployee[]> {
    const username = this.config.get<string>('ODOO_SERVICE_USERNAME', '');
    const apiKey = this.getServiceCredential();
    if (!username || !apiKey) {
      this.logger.warn(
        'Odoo service credentials not configured, skipping employee fetch',
      );
      return [];
    }

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'hr.employee',
              'search_read',
              [[['active', '=', true]]],
              {
                fields: [
                  'name',
                  'work_email',
                  'work_phone',
                  'department_id',
                  'job_title',
                  'user_id',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      console.log('Odoo fetchEmployees response:', response.data);

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchEmployees');
        return [];
      }

      return result as OdooEmployee[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;

      // Reset cached UID on auth failure so next call re-authenticates
      this.serviceUid = null;

      if (
        axios.isAxiosError(error) &&
        (error.code === 'ECONNABORTED' || !error.response)
      ) {
        this.logger.error(
          `Odoo unreachable during employee fetch: ${error.message}`,
        );
        throw new ServiceUnavailableException('Odoo unreachable');
      }

      this.logger.error(`Odoo fetchEmployees error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch employees from Odoo',
      );
    }
  }

  async writeAttendance(
    odooEmployeeId: number,
    checkinAt: Date,
    checkoutAt?: Date | null,
  ): Promise<number> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) {
      this.logger.warn(
        'Odoo API key not configured, skipping attendance write',
      );
      return 0;
    }

    const uid = await this.authenticateServiceAccount();
    if (!uid) return 0;

    const formatDt = (d: Date) =>
      d.toISOString().replace('T', ' ').substring(0, 19);

    const vals: Record<string, unknown> = {
      employee_id: odooEmployeeId,
      check_in: formatDt(checkinAt),
    };
    if (checkoutAt) {
      vals.check_out = formatDt(checkoutAt);
    }

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [this.odooDb, uid, apiKey, 'hr.attendance', 'create', [vals]],
        },
      },
      { timeout: 30_000 },
    );

    const result = response.data?.result;
    if (typeof result !== 'number') {
      this.logger.error('Unexpected Odoo response for writeAttendance');
      throw new ServiceUnavailableException(
        'Failed to write attendance to Odoo',
      );
    }

    return result;
  }

  async findEmployeeIdByUserUidOrEmployeeId(
    odooUid: number,
  ): Promise<number | null> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return null;

    const uid = await this.authenticateServiceAccount();
    if (!uid) return null;

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'hr.employee',
            'search_read',
            [[['user_id', '=', odooUid]]],
            { fields: ['id'], limit: 1 },
          ],
        },
      },
      { timeout: 30_000 },
    );

    const byUser = response.data?.result;
    if (Array.isArray(byUser) && byUser.length > 0 && byUser[0]?.id) {
      return Number(byUser[0].id);
    }

    const fallback = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'hr.employee',
            'search_read',
            [[['id', '=', odooUid]]],
            { fields: ['id'], limit: 1 },
          ],
        },
      },
      { timeout: 30_000 },
    );
    const byId = fallback.data?.result;
    if (Array.isArray(byId) && byId.length > 0 && byId[0]?.id) {
      return Number(byId[0].id);
    }

    return null;
  }

  async createAttendanceCheckIn(
    odooEmployeeId: number,
    checkinAt: Date,
  ): Promise<number> {
    return this.writeAttendance(odooEmployeeId, checkinAt);
  }

  async checkoutAttendance(
    odooAttendanceId: number,
    checkoutAt: Date,
  ): Promise<boolean> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) {
      this.logger.warn(
        'Odoo API key not configured, skipping attendance checkout write',
      );
      return false;
    }

    const uid = await this.authenticateServiceAccount();
    if (!uid) return false;

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'hr.attendance',
            'write',
            [
              [odooAttendanceId],
              { check_out: this.formatDateTime(checkoutAt) },
            ],
          ],
        },
      },
      { timeout: 30_000 },
    );

    return response.data?.result === true;
  }

  async findOpenAttendance(
    odooEmployeeId: number,
    referenceDate = new Date(),
  ): Promise<OdooAttendanceRecord | null> {
    const { start, end } = this.getHoChiMinhDayRange(referenceDate);
    const records = await this.fetchAttendanceHistory(
      odooEmployeeId,
      start,
      end,
    );
    return records.find((record) => !record.check_out) ?? null;
  }

  async findAutoCheckoutAttendance(
    odooEmployeeId: number,
    scheduledAt: Date,
  ): Promise<OdooAttendanceRecord | null> {
    const { start, end } = this.getHoChiMinhDayRange(scheduledAt);
    const records = await this.fetchAttendanceHistory(
      odooEmployeeId,
      start,
      end,
    );
    const scheduledAtKey = this.formatDateTime(scheduledAt);

    return (
      records.find(
        (record) => !record.check_out && record.check_in <= scheduledAtKey,
      ) ?? null
    );
  }

  async fetchTodayAttendance(
    odooEmployeeId: number,
    referenceDate = new Date(),
  ): Promise<OdooAttendanceRecord[]> {
    const { start, end } = this.getHoChiMinhDayRange(referenceDate);
    return this.fetchAttendanceHistory(odooEmployeeId, start, end);
  }

  async fetchAttendanceHistory(
    odooEmployeeId: number,
    from: Date,
    to: Date,
  ): Promise<OdooAttendanceRecord[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    const uid = await this.authenticateServiceAccount();
    if (!uid) return [];

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'hr.attendance',
            'search_read',
            [
              [
                ['employee_id', '=', odooEmployeeId],
                ['check_in', '>=', this.formatDateTime(from)],
                ['check_in', '<', this.formatDateTime(to)],
              ],
            ],
            {
              fields: ['employee_id', 'check_in', 'check_out', 'worked_hours'],
              order: 'check_in desc',
            },
          ],
        },
      },
      { timeout: 30_000 },
    );

    const result = response.data?.result;
    if (!Array.isArray(result)) {
      this.logger.error('Unexpected Odoo response for fetchAttendanceHistory');
      throw new ServiceUnavailableException(
        'Failed to fetch attendance from Odoo',
      );
    }

    return result as OdooAttendanceRecord[];
  }

  private formatDateTime(d: Date): string {
    return d.toISOString().replace('T', ' ').substring(0, 19);
  }

  private getDayRange(referenceDate: Date) {
    const start = new Date(referenceDate);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 1);
    return { start, end };
  }

  getHoChiMinhDayRange(referenceDate: Date) {
    // Convert to Vietnam local time using a fixed UTC+7 offset, then project
    // the local midnight boundaries back into UTC for Odoo queries.
    const localMillis =
      referenceDate.getTime() + this.attendanceTimezoneOffsetMs;
    const localStart = new Date(localMillis);
    localStart.setUTCHours(0, 0, 0, 0);

    const start = new Date(
      localStart.getTime() - this.attendanceTimezoneOffsetMs,
    );
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    return { start, end };
  }

  async fetchProjects(odooUid?: number): Promise<OdooProject[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const domain: unknown[] = odooUid
        ? [
            '|',
            ['user_id', '=', odooUid],
            ['task_ids.user_ids', 'in', [odooUid]],
          ]
        : [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.project',
              'search_read',
              [domain],
              {
                fields: ['name', 'user_id', 'date_start', 'date', 'task_count'],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchProjects');
        return [];
      }
      return result as OdooProject[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchProjects error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch projects from Odoo',
      );
    }
  }

  async fetchTasks(
    projectId: number,
    includeSubtasks = false,
  ): Promise<OdooTask[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task',
              'search_read',
              [
                includeSubtasks
                  ? [['project_id', '=', projectId]]
                  : [
                      ['project_id', '=', projectId],
                      ['parent_id', '=', false],
                    ],
              ],
              {
                fields: [
                  'name',
                  'project_id',
                  'user_ids',
                  'stage_id',
                  'tag_ids',
                  'date_deadline',
                  'priority',
                  'description',
                  'parent_id',
                  'child_ids',
                  'subtask_count',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchTasks');
        return [];
      }
      return result as OdooTask[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTasks error: ${error}`);
      throw new ServiceUnavailableException('Failed to fetch tasks from Odoo');
    }
  }

  async fetchTasksByUser(odooUid: number): Promise<OdooTask[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task',
              'search_read',
              [[['user_ids', 'in', [odooUid]]]],
              {
                fields: [
                  'name',
                  'project_id',
                  'user_ids',
                  'stage_id',
                  'tag_ids',
                  'date_deadline',
                  'priority',
                  'description',
                  'parent_id',
                  'child_ids',
                  'subtask_count',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchTasksByUser');
        return [];
      }
      return result as OdooTask[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTasksByUser error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch user tasks from Odoo',
      );
    }
  }

  async fetchTaskById(taskId: number): Promise<OdooTask | null> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return null;

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return null;

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task',
              'search_read',
              [[['id', '=', taskId]]],
              {
                fields: [
                  'name',
                  'project_id',
                  'user_ids',
                  'stage_id',
                  'tag_ids',
                  'date_deadline',
                  'priority',
                  'description',
                  'parent_id',
                  'child_ids',
                  'subtask_count',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result) || result.length === 0) return null;
      return result[0] as OdooTask;
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTaskById error: ${error}`);
      throw new ServiceUnavailableException('Failed to fetch task from Odoo');
    }
  }

  async fetchSubtasks(parentId: number): Promise<OdooTask[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task',
              'search_read',
              [[['parent_id', '=', parentId]]],
              {
                fields: [
                  'name',
                  'project_id',
                  'user_ids',
                  'stage_id',
                  'tag_ids',
                  'date_deadline',
                  'priority',
                  'description',
                  'parent_id',
                  'child_ids',
                  'subtask_count',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchSubtasks');
        return [];
      }
      return result as OdooTask[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchSubtasks error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch subtasks from Odoo',
      );
    }
  }

  async fetchTasksByStageIds(stageIds: number[]): Promise<OdooTask[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) {
      console.log('Odoo API key not configured, skipping fetchTasksByStageIds');
      return [];
    }

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) {
        console.log(
          'Odoo service account auth failed, skipping fetchTasksByStageIds',
        );
        return [];
      }

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task',
              'search_read',
              [[['stage_id', 'in', stageIds]]],
              {
                fields: [
                  'name',
                  'project_id',
                  'user_ids',
                  'stage_id',
                  'tag_ids',
                  'date_deadline',
                  'priority',
                  'description',
                  'parent_id',
                  'child_ids',
                  'subtask_count',
                ],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchTasksByStageIds');
        return [];
      }
      return result as OdooTask[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTasksByStageIds error: ${error}`);
      throw new ServiceUnavailableException('Failed to fetch tasks from Odoo');
    }
  }

  async fetchTaskStages(): Promise<OdooTaskStage[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.task.type',
              'search_read',
              [[]],
              {
                fields: ['name', 'sequence', 'project_ids'],
                order: 'sequence asc',
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchTaskStages');
        return [];
      }
      return result as OdooTaskStage[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTaskStages error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch task stages from Odoo',
      );
    }
  }

  async inspectNextTaskStage(
    projectId: number,
    currentStageId: number,
  ): Promise<OdooTaskStageAdvanceDecision> {
    const stages = await this.fetchTaskStages();
    const applicableStages = this.selectStagePipelineForProject(
      stages,
      projectId,
    ).sort((a, b) => {
      if (a.sequence !== b.sequence) {
        return a.sequence - b.sequence;
      }
      return a.id - b.id;
    });

    const currentStage = applicableStages.find(
      (stage) => stage.id === currentStageId,
    );
    if (!currentStage) {
      return { status: 'unresolved_pipeline' };
    }

    const higherStages = applicableStages.filter(
      (stage) => stage.sequence > currentStage.sequence,
    );
    if (higherStages.length === 0) {
      return { status: 'terminal_stage' };
    }

    const nextSequence = higherStages[0].sequence;
    const nextCandidates = higherStages.filter(
      (stage) => stage.sequence === nextSequence,
    );

    if (nextCandidates.length !== 1) {
      return { status: 'unresolved_pipeline' };
    }

    return { status: 'advance', nextStage: nextCandidates[0] };
  }

  async resolveNextTaskStage(
    projectId: number,
    currentStageId: number,
  ): Promise<OdooTaskStage | null> {
    const decision = await this.inspectNextTaskStage(projectId, currentStageId);
    if (decision.status !== 'advance') {
      return null;
    }

    return decision.nextStage;
  }

  async advanceTaskStage(taskId: number, stageId: number): Promise<boolean> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return false;

    const uid = await this.authenticateServiceAccount();
    if (!uid) return false;

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'project.task',
            'write',
            [[taskId], { stage_id: stageId }],
          ],
        },
      },
      { timeout: 30_000 },
    );

    return response.data?.result === true;
  }

  async fetchProjectTags(): Promise<OdooTaskTag[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'project.tags',
              'search_read',
              [[]],
              {
                fields: ['name'],
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchProjectTags');
        return [];
      }
      return result as OdooTaskTag[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchProjectTags error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch project tags from Odoo',
      );
    }
  }

  async fetchTaskLogNotes(taskId: number): Promise<OdooLogNote[]> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return [];

    try {
      const uid = await this.authenticateServiceAccount();
      if (!uid) return [];

      const response = await axios.post(
        `${this.odooUrl}/jsonrpc`,
        {
          jsonrpc: '2.0',
          method: 'call',
          params: {
            service: 'object',
            method: 'execute_kw',
            args: [
              this.odooDb,
              uid,
              apiKey,
              'mail.message',
              'search_read',
              [
                [
                  ['model', '=', 'project.task'],
                  ['res_id', '=', taskId],
                  ['message_type', 'in', ['comment', 'notification']],
                ],
              ],
              {
                fields: ['body', 'author_id', 'date', 'message_type'],
                order: 'date desc',
              },
            ],
          },
        },
        { timeout: 30_000 },
      );

      const result = response.data?.result;
      if (!Array.isArray(result)) {
        this.logger.error('Unexpected Odoo response for fetchTaskLogNotes');
        return [];
      }
      return result as OdooLogNote[];
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      this.serviceUid = null;
      this.logger.error(`Odoo fetchTaskLogNotes error: ${error}`);
      throw new ServiceUnavailableException(
        'Failed to fetch task log notes from Odoo',
      );
    }
  }

  async writeTaskLogNote(
    taskId: number,
    body: string,
    authorOdooUid?: number,
  ): Promise<number> {
    const apiKey = this.getServiceCredential();
    if (!apiKey) return 0;

    const uid = await this.authenticateServiceAccount();
    if (!uid) return 0;

    const response = await axios.post(
      `${this.odooUrl}/jsonrpc`,
      {
        jsonrpc: '2.0',
        method: 'call',
        params: {
          service: 'object',
          method: 'execute_kw',
          args: [
            this.odooDb,
            uid,
            apiKey,
            'mail.message',
            'create',
            [
              {
                model: 'project.task',
                res_id: taskId,
                body,
                message_type: 'comment',
                ...(authorOdooUid ? { author_id: authorOdooUid } : {}),
              },
            ],
          ],
        },
      },
      { timeout: 30_000 },
    );

    const result = response.data?.result;
    if (typeof result !== 'number') {
      this.logger.error('Unexpected Odoo response for writeTaskLogNote');
      throw new ServiceUnavailableException(
        'Failed to write task log note to Odoo',
      );
    }
    return result;
  }

  private selectStagePipelineForProject(
    stages: OdooTaskStage[],
    projectId: number,
  ): OdooTaskStage[] {
    const explicitStages = stages.filter((stage) =>
      Array.isArray(stage.project_ids)
        ? stage.project_ids.includes(projectId)
        : false,
    );

    if (explicitStages.length > 0) {
      return explicitStages;
    }

    return stages.filter((stage) => this.isGlobalStage(stage));
  }

  private isGlobalStage(stage: OdooTaskStage): boolean {
    return !Array.isArray(stage.project_ids) || stage.project_ids.length === 0;
  }
}
