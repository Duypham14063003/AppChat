import {
  Injectable,
  Logger,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import { RtcTokenBuilder, RtcRole } from 'agora-token';
import { RedisPubSubService } from '../../chat/services/redis-pubsub.service.js';
import { ConnectionManager } from '../../chat/services/connection-manager.service.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { ApnsService } from '../../notification/services/apns.service.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { Call } from '../entities/call.entity.js';
import { StartCallDto } from '../dto/call.dto.js';
import { ChatService } from '../../chat/services/chat.service.js';
import * as crypto from 'crypto';

@Injectable()
export class CallService {
  private readonly logger = new Logger(CallService.name);

  /** Authoritative ring duration. A ringing call older than this is missed. */
  private static readonly RING_TIMEOUT_MS = 45000;
  /** Minimum age before a not-yet-accepted ringing call may be ended. */
  private static readonly MIN_END_GUARD_MS = 1000;

  /** In-process timers that fire the missed-call transition per call id. */
  private readonly ringTimeouts = new Map<string, NodeJS.Timeout>();

  constructor(
    @InjectRepository(Call)
    private readonly callRepo: Repository<Call>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly config: ConfigService,
    private readonly redisPubSub: RedisPubSubService,
    private readonly connectionManager: ConnectionManager,
    private readonly firebaseService: FirebaseService,
    private readonly apnsService: ApnsService,
    private readonly chatService: ChatService,
  ) {}

  // --- Core Call Lifecycle ---

  async startCall(
    callerId: string,
    dto: StartCallDto,
    actorSessionId?: string,
  ) {
    let actorSessionSuffix = '';
    if (actorSessionId) {
      const actorSession = await this.sessionRepo.findOne({
        where: { id: actorSessionId },
        select: ['id', 'device_id', 'device_name', 'last_ip'],
      });
      actorSessionSuffix = actorSession
          ? `, actorSessionId=${actorSession.id}, actorDevice=${actorSession.device_name ?? 'unknown'}, actorDeviceId=${actorSession.device_id ?? 'unknown'}, actorIp=${actorSession.last_ip ?? 'unknown'}`
          : `, actorSessionId=${actorSessionId}, actorSessionLookup=missing`;
    }
    this.logger.log(
      `startCall: callerId=${callerId}, receiverId=${dto.receiverId}, type=${dto.type}${actorSessionSuffix}`,
    );

    // Validate: Cannot call self
    if (callerId === dto.receiverId) {
      throw new BadRequestException('Không thể gọi cho chính mình');
    }

    // Validate: Receiver exists
    const receiver = await this.userRepo.findOne({
      where: { id: dto.receiverId },
    });
    if (!receiver) {
      throw new BadRequestException('Người nhận không tồn tại');
    }

    const channelName = `call_${callerId.split('-')[0]}_${dto.receiverId.split('-')[0]}_${Date.now()}`;

    // 1. kiểm tra người gọi có đang bận không
    const callerActiveCalls = await this.callRepo.find({
      where: [
        { receiver_id: callerId, status: In(['ringing', 'accepted']) },
        { caller_id: callerId, status: In(['ringing', 'accepted']) },
      ],
    });

    let callerActiveCall = null;
    for (const c of callerActiveCalls) {
      if (c.status === 'ringing') {
        const refTime = c.started_at || c.created_at;
        const age = Date.now() - refTime.getTime();
        if (age > 60000) {
          c.status = 'ended';
          c.ended_at = new Date();
          await this.callRepo.save(c);
          continue;
        }
      } else if (c.status === 'accepted') {
        const refTime = c.accepted_at || c.started_at || c.created_at;
        const age = Date.now() - refTime.getTime();
        if (age > 12 * 3600000) {
          c.status = 'ended';
          c.ended_at = new Date();
          await this.callRepo.save(c);
          continue;
        }
      }
      callerActiveCall = c;
      break;
    }

    if (callerActiveCall) {
      this.logger.warn(
        `startCall: caller ${callerId} is already in an active call (${callerActiveCall.id})`,
      );
      throw new BadRequestException('Bạn đang trong cuộc gọi khác');
    }

    // 2. Kiểm tra trạng thái bận phía máy nhận
    const activeCalls = await this.callRepo.find({
      where: [
        { receiver_id: dto.receiverId, status: In(['ringing', 'accepted']) },
        { caller_id: dto.receiverId, status: In(['ringing', 'accepted']) },
      ],
    });

    const isReceiverOnline = this.connectionManager.isOnline(dto.receiverId);

    let activeCall = null;
    for (const c of activeCalls) {
      if (!isReceiverOnline) {
        this.logger.log(
          `startCall: receiver is offline, ending active call ${c.id}`,
        );
        c.status = 'ended';
        c.ended_at = new Date();
        await this.callRepo.save(c);
        continue;
      }

      if (c.status === 'ringing') {
        const refTime = c.started_at || c.created_at;
        const age = Date.now() - refTime.getTime();
        if (age > 60000) {
          this.logger.log(
            `startCall: receiver active call ${c.id} ringing timed out, ending call`,
          );
          c.status = 'ended';
          c.ended_at = new Date();
          await this.callRepo.save(c);
          continue;
        }
      } else if (c.status === 'accepted') {
        const refTime = c.accepted_at || c.started_at || c.created_at;
        const age = Date.now() - refTime.getTime();
        if (age > 12 * 3600000) {
          this.logger.log(
            `startCall: receiver active call ${c.id} accepted timed out, ending call`,
          );
          c.status = 'ended';
          c.ended_at = new Date();
          await this.callRepo.save(c);
          continue;
        }
      }
      activeCall = c;
      break;
    }

    if (activeCall) {
      this.logger.warn(
        `startCall: receiver ${dto.receiverId} is busy (activeCall=${activeCall.id})`,
      );
      const call = this.callRepo.create({
        caller_id: callerId,
        receiver_id: dto.receiverId,
        channel_name: channelName,
        type: dto.type,
        status: 'rejected', // Save as 'rejected' in DB to avoid Postgres enum type error
        started_at: new Date(),
        ended_at: new Date(),
      });
      const savedCall = await this.callRepo.save(call);

      // Send WebSocket event call_busy to caller
      this.logger.log(
        `startCall: Emitting call_busy to caller ${callerId} for callId=${savedCall.id}`,
      );
      const busyPayload = {
        _event: 'call_busy',
        call_id: savedCall.id,
      };
      await this.redisPubSub.publishUserEvent(callerId, busyPayload);

      // Send FCM Push fallback for busy status
      this.sendCallFcmPush(callerId, {
        type: 'call_busy',
        call_id: savedCall.id,
      }).catch((err) => {
        this.logger.error(`Failed to send call_busy push: ${err.message}`);
      });

      // Send system message to chat
      try {
        const conv = await this.chatService.createDirectConversation(
          callerId,
          dto.receiverId,
        );
        await this.chatService.sendMessage(callerId, {
          id: crypto.randomUUID(),
          conv_id: conv.id,
          type: 'system',
          content: 'Người nhận đang bận',
        });
      } catch (e) {
        this.logger.error('Failed to create call busy message', e);
      }

      return { ...savedCall, status: 'busy', busy: true } as any;
    }

    const call = this.callRepo.create({
      caller_id: callerId,
      receiver_id: dto.receiverId,
      channel_name: channelName,
      type: dto.type,
      status: 'ringing',
      started_at: new Date(),
    });

    const savedCall = await this.callRepo.save(call);
    this.logger.log(
      `startCall: Created call ${savedCall.id} in ringing status`,
    );

    // Emit socket for receiver (if online)
    const payload = {
      _event: 'incoming_call',
      call_id: savedCall.id,
      caller_id: callerId,
      channel_name: channelName,
      type: dto.type,
    };

    if (this.connectionManager.isOnline(dto.receiverId)) {
      this.logger.log(
        `startCall: Emitting incoming_call to receiver ${dto.receiverId} via WS`,
      );
      await this.redisPubSub.publishUserEvent(dto.receiverId, payload);
    } else {
      this.logger.log(
        `startCall: Receiver ${dto.receiverId} is offline via WS`,
      );
    }

    // Send FCM Push Notification asynchronously (do not await, to return HTTP response instantly)
    const caller = await this.userRepo.findOne({
      where: { id: callerId },
      select: ['id', 'name', 'avatar_url'],
    });

    this.logger.log(
      `startCall: Sending FCM call_invite to receiver ${dto.receiverId}`,
    );
    this.sendCallFcmPush(dto.receiverId, {
      type: 'call_invite',
      call_id: savedCall.id,
      caller_id: callerId,
      caller_name: caller?.name || 'Người gọi',
      caller_avatar: caller?.avatar_url || '',
      channel_name: channelName,
      call_type: dto.type,
    }).catch((err) => {
      this.logger.error(`Failed to send call push: ${err.message}`);
    });

    this.scheduleRingTimeout(savedCall.id);

    return savedCall;
  }

  async acceptCall(userId: string, callId: string) {
    this.logger.log(`acceptCall: userId=${userId}, callId=${callId}`);
    const call = await this.getCallOrThrow(callId);
    if (call.receiver_id !== userId) {
      this.logger.warn(
        `acceptCall: userId=${userId} forbidden to accept callId=${callId}`,
      );
      throw new ForbiddenException('Chỉ người nhận mới có thể chấp nhận');
    }
    if (call.status !== 'ringing') {
      this.logger.log(
        `acceptCall: callId=${callId} already ${call.status}, ignoring`,
      );
      return call;
    }

    call.status = 'accepted';
    call.accepted_at = new Date();
    await this.callRepo.save(call);
    this.logger.log(`acceptCall: callId=${callId} status updated to accepted`);
    this.clearRingTimeout(callId);

    // Emit for caller
    this.logger.log(
      `acceptCall: Emitting call_accepted to caller ${call.caller_id}`,
    );
    await this.redisPubSub.publishUserEvent(call.caller_id, {
      _event: 'call_accepted',
      call_id: call.id,
      accepted_by: userId,
    });

    // Send FCM Push Notification to notify caller that receiver accepted
    this.logger.log(
      `acceptCall: Sending FCM call_accepted to caller ${call.caller_id}`,
    );
    this.sendCallFcmPush(call.caller_id, {
      type: 'call_accepted',
      call_id: call.id,
    }).catch((err) => {
      this.logger.error(`Failed to send call_accepted push: ${err.message}`);
    });

    return {
      ...call,
      agora: this.generateAgoraData(userId, call.channel_name),
    };
  }

  async rejectCall(userId: string, callId: string) {
    this.logger.log(`rejectCall: userId=${userId}, callId=${callId}`);
    const call = await this.getCallOrThrow(callId);
    if (call.receiver_id !== userId) {
      this.logger.warn(
        `rejectCall: userId=${userId} forbidden to reject callId=${callId}`,
      );
      throw new ForbiddenException();
    }

    // Status guard: Only allow rejecting if the call is currently 'ringing'
    if (call.status !== 'ringing') {
      this.logger.warn(
        `rejectCall: callId=${callId} is already ${call.status}, ignoring`,
      );
      return { message: 'Already processed' };
    }

    call.status = 'rejected';
    call.ended_at = new Date();
    await this.callRepo.save(call);
    this.logger.log(`rejectCall: callId=${callId} status updated to rejected`);
    this.clearRingTimeout(callId);

    this.logger.log(
      `rejectCall: Emitting call_rejected to caller ${call.caller_id}`,
    );
    await this.redisPubSub.publishUserEvent(call.caller_id, {
      _event: 'call_rejected',
      call_id: call.id,
    });

    // Send FCM Push Notification to notify background caller to dismiss CallKit
    this.logger.log(
      `rejectCall: Sending FCM call_rejected to caller ${call.caller_id}`,
    );
    this.sendCallFcmPush(call.caller_id, {
      type: 'call_rejected',
      call_id: call.id,
    }).catch((err) => {
      this.logger.error(`Failed to send call_rejected push: ${err.message}`);
    });

    try {
      const conv = await this.chatService.createDirectConversation(
        call.caller_id,
        call.receiver_id,
      );
      await this.chatService.sendMessage(call.caller_id, {
        id: crypto.randomUUID(),
        conv_id: conv.id,
        type: 'system',
        content:
          call.type === 'video'
            ? 'Cuộc gọi video bị từ chối'
            : 'Cuộc gọi thoại bị từ chối',
      });
    } catch (e) {
      this.logger.error('Failed to create call rejected message', e);
    }

    return { message: 'Rejected' };
  }

  async endCall(userId: string, callId: string, actorSessionId?: string) {
    let actorSessionSuffix = '';
    if (actorSessionId) {
      const actorSession = await this.sessionRepo.findOne({
        where: { id: actorSessionId },
        select: ['id', 'device_id', 'device_name', 'last_ip'],
      });
      actorSessionSuffix = actorSession
          ? `, actorSessionId=${actorSession.id}, actorDevice=${actorSession.device_name ?? 'unknown'}, actorDeviceId=${actorSession.device_id ?? 'unknown'}, actorIp=${actorSession.last_ip ?? 'unknown'}`
          : `, actorSessionId=${actorSessionId}, actorSessionLookup=missing`;
    }
    this.logger.log(
      `endCall: userId=${userId}, callId=${callId}${actorSessionSuffix}`,
    );
    const call = await this.getCallOrThrow(callId);
    if (call.caller_id !== userId && call.receiver_id !== userId) {
      this.logger.warn(
        `endCall: userId=${userId} forbidden to end callId=${callId}`,
      );
      throw new ForbiddenException();
    }
    if (call.status === 'ended') {
      this.logger.log(`endCall: callId=${callId} already ended, ignoring`);
      return call;
    }

    // Premature-end guard: an end request for a still-ringing, not-yet-accepted
    // call that arrives within MIN_END_GUARD_MS of creation is treated as a
    // no-op. This is a server-side defense against the client auto-firing
    // endCall immediately after startCall (observed ~53ms in production).
    // A human cannot start and cancel a call within this window, so legitimate
    // user cancels are never blocked. Accepted calls are never guarded.
    if (call.status === 'ringing' && !call.accepted_at) {
      const refTime = call.started_at || call.created_at;
      const age = Date.now() - refTime.getTime();
      if (age < CallService.MIN_END_GUARD_MS) {
        this.logger.warn(
          `endCall: callId=${callId} end ignored (no-op) — within ${CallService.MIN_END_GUARD_MS}ms guard window (age=${age}ms)`,
        );
        return call;
      }
    }

    const now = new Date();
    call.status = 'ended';
    call.ended_at = now;

    if (call.accepted_at) {
      call.duration = Math.floor(
        (now.getTime() - call.accepted_at.getTime()) / 1000,
      );
    }

    await this.callRepo.save(call);
    this.logger.log(
      `endCall: callId=${callId} status updated to ended, duration=${call.duration}`,
    );
    this.clearRingTimeout(callId);

    const otherUser =
      call.caller_id === userId ? call.receiver_id : call.caller_id;
    this.logger.log(`endCall: Emitting call_ended to otherUser ${otherUser}`);
    await this.redisPubSub.publishUserEvent(otherUser, {
      _event: 'call_ended',
      call_id: call.id,
      duration: call.duration,
    });

    // Send FCM Push Notification to notify background participant to dismiss CallKit
    this.logger.log(
      `endCall: Sending FCM call_ended to otherUser ${otherUser}`,
    );
    this.sendCallFcmPush(otherUser, {
      type: 'call_ended',
      call_id: call.id,
    }).catch((err) => {
      this.logger.error(`Failed to send call_ended push: ${err.message}`);
    });

    try {
      const conv = await this.chatService.createDirectConversation(
        call.caller_id,
        call.receiver_id,
      );
      let content = '';
      if (call.duration != null && call.duration > 0) {
        const mins = Math.floor(call.duration / 60)
          .toString()
          .padStart(2, '0');
        const secs = (call.duration % 60).toString().padStart(2, '0');
        content = `Cuộc gọi ${call.type === 'video' ? 'video' : 'thoại'} kết thúc (${mins}:${secs})`;
      } else {
        content =
          call.caller_id === userId
            ? `Cuộc gọi ${call.type === 'video' ? 'video' : 'thoại'} bị hủy`
            : `Cuộc gọi nhỡ`;
      }

      await this.chatService.sendMessage(call.caller_id, {
        id: crypto.randomUUID(),
        conv_id: conv.id,
        type: 'system',
        content,
      });
    } catch (e) {
      this.logger.error('Failed to create call ended message', e);
    }

    return call;
  }

  // --- Ring timeout (backend-owned) ---

  /**
   * Schedule the missed-call transition for a ringing call. The backend owns
   * the ring lifetime; the client must not drive teardown via its own timer.
   */
  private scheduleRingTimeout(callId: string): void {
    this.clearRingTimeout(callId);
    const timer = setTimeout(() => {
      this.ringTimeouts.delete(callId);
      this.handleRingTimeout(callId).catch((err) => {
        this.logger.error(
          `handleRingTimeout failed for call ${callId}: ${err.message}`,
        );
      });
    }, CallService.RING_TIMEOUT_MS);
    // Do not keep the event loop alive solely for this timer.
    if (typeof timer.unref === 'function') timer.unref();
    this.ringTimeouts.set(callId, timer);
  }

  private clearRingTimeout(callId: string): void {
    const timer = this.ringTimeouts.get(callId);
    if (timer) {
      clearTimeout(timer);
      this.ringTimeouts.delete(callId);
    }
  }

  /**
   * Transition a still-ringing call to missed and notify both participants so
   * their UI clears. Idempotent: if the call already left ringing, do nothing.
   */
  private async handleRingTimeout(callId: string): Promise<void> {
    const call = await this.callRepo.findOne({ where: { id: callId } });
    if (!call || call.status !== 'ringing') return;

    call.status = 'missed';
    call.ended_at = new Date();
    await this.callRepo.save(call);
    this.logger.log(
      `handleRingTimeout: callId=${callId} transitioned to missed after ${CallService.RING_TIMEOUT_MS}ms`,
    );

    for (const userId of [call.caller_id, call.receiver_id]) {
      await this.redisPubSub.publishUserEvent(userId, {
        _event: 'call_ended',
        call_id: call.id,
        reason: 'missed',
        duration: 0,
      });
    }

    this.sendCallFcmPush(call.receiver_id, {
      type: 'call_ended',
      call_id: call.id,
    }).catch((err) => {
      this.logger.error(`Failed to send missed-call push: ${err.message}`);
    });
  }

  // --- Signaling (Legacy relay support) ---

  async handleCallInvite(callerId: string, data: any) {
    this.logger.log(
      `handleCallInvite legacy: callerId=${callerId}, to_user_id=${data.to_user_id}`,
    );
    return this.startCall(callerId, {
      receiverId: data.to_user_id,
      type: data.type || 'audio',
    });
  }

  async handleCallAccept(recipientId: string, data: any) {
    this.logger.log(
      `handleCallAccept legacy: recipientId=${recipientId}, call_id=${data.call_id}`,
    );
    return this.acceptCall(recipientId, data.call_id);
  }

  async handleCallReject(senderId: string, data: any) {
    this.logger.log(
      `handleCallReject legacy: senderId=${senderId}, call_id=${data.call_id}`,
    );
    return this.rejectCall(senderId, data.call_id);
  }

  async handleCallHangup(senderId: string, data: any) {
    this.logger.log(
      `handleCallHangup legacy: senderId=${senderId}, call_id=${data.call_id}`,
    );
    return this.endCall(senderId, data.call_id);
  }

  async handleWebRtcSignal(senderId: string, data: any) {
    const { to_user_id, call_id, signal } = data;
    this.logger.log(
      `handleWebRtcSignal legacy: senderId=${senderId}, to_user_id=${to_user_id}, callId=${call_id}`,
    );
    await this.redisPubSub.publishUserEvent(to_user_id, {
      _event: 'webrtc_signal',
      from_user_id: senderId,
      call_id,
      signal,
    });
  }

  // --- Agora & History ---

  async getAgoraToken(userId: string, callId: string) {
    this.logger.log(`getAgoraToken: userId=${userId}, callId=${callId}`);
    const call = await this.getCallOrThrow(callId);
    if (call.caller_id !== userId && call.receiver_id !== userId) {
      this.logger.warn(
        `getAgoraToken: userId=${userId} forbidden for callId=${callId}`,
      );
      throw new ForbiddenException();
    }

    return this.generateAgoraData(userId, call.channel_name);
  }

  async getHistory(userId: string) {
    this.logger.log(`getHistory: userId=${userId}`);
    return this.callRepo.find({
      where: [{ caller_id: userId }, { receiver_id: userId }],
      order: { created_at: 'DESC' },
      take: 50,
    });
  }

  /**
   * Trả về cuộc gọi đến đang chờ (ringing) mà user là người nhận.
   * Dùng để client đồng bộ lại khi WS (re)connect hoặc app resume,
   * tránh mất sự kiện incoming_call khi socket bị rớt/zombie.
   */
  async getActiveIncomingCall(userId: string) {
    const call = await this.callRepo.findOne({
      where: { receiver_id: userId, status: 'ringing' },
      order: { created_at: 'DESC' },
    });

    if (!call) return null;

    // Bỏ qua cuộc gọi đã quá hạn ringing (> ring timeout), khớp với
    // backend-owned ring timeout — call quá hạn sẽ được chuyển 'missed'.
    const refTime = call.started_at || call.created_at;
    const age = Date.now() - refTime.getTime();
    if (age > CallService.RING_TIMEOUT_MS) {
      this.logger.log(
        `getActiveIncomingCall: ringing call ${call.id} is stale (${age}ms), ignoring`,
      );
      return null;
    }

    const caller = await this.userRepo.findOne({
      where: { id: call.caller_id },
      select: ['id', 'name', 'avatar_url'],
    });

    this.logger.log(
      `getActiveIncomingCall: userId=${userId} has pending call ${call.id}`,
    );

    return {
      call_id: call.id,
      caller_id: call.caller_id,
      caller_name: caller?.name || 'Người gọi',
      caller_avatar: caller?.avatar_url || '',
      channel_name: call.channel_name,
      type: call.type,
    };
  }

  async handleUserDisconnect(userId: string) {
    this.logger.log(`handleUserDisconnect: userId=${userId}`);
    // Only auto-end calls that have progressed past ringing. A ringing call
    // must NOT be ended just because a WebSocket dropped (iOS apps briefly
    // background while dialing). Ringing calls are governed solely by the
    // backend ring timeout and explicit user actions.
    const activeCalls = await this.callRepo.find({
      where: [
        { caller_id: userId, status: In(['accepted']) },
        { receiver_id: userId, status: In(['accepted']) },
      ],
    });

    if (activeCalls.length === 0) return;

    for (const call of activeCalls) {
      this.logger.log(
        `handleUserDisconnect: Automatically ending call ${call.id} for disconnected user ${userId}`,
      );
      try {
        await this.endCall(userId, call.id);
      } catch (err: any) {
        this.logger.error(
          `Failed to auto-end call ${call.id} on disconnect: ${err.message}`,
        );
      }
    }
  }

  // --- Helpers ---

  private generateAgoraData(userId: string, channelName: string) {
    const appId = this.config.get<string>('AGORA_APP_ID', '');
    const appCertificate = this.config.get<string>('AGORA_APP_CERTIFICATE', '');
    if (!appId || !appCertificate) {
      this.logger.error('AGORA_APP_ID or AGORA_APP_CERTIFICATE not set');
    }

    const uid = this.hashUserIdToNumber(userId);
    const expirationTimeInSeconds = 3600; // 1h
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
      privilegeExpiredTs,
    );

    return { token, appId, channelName, uid };
  }

  private async getCallOrThrow(id: string) {
    const call = await this.callRepo.findOne({ where: { id } });
    if (!call) {
      this.logger.error(`getCallOrThrow: callId=${id} not found`);
      throw new NotFoundException('Cuộc gọi không tồn tại');
    }
    return call;
  }

  private hashUserIdToNumber(userId: string): number {
    return parseInt(userId.replace(/-/g, '').substring(0, 8), 16);
  }

  private async sendCallFcmPush(userId: string, data: Record<string, string>) {
    this.logger.log(`sendCallFcmPush: userId=${userId}, type=${data.type}`);
    try {
      const sessions = await this.sessionRepo.find({
        where: { user_id: userId },
        select: ['id', 'device_name', 'fcm_token', 'voip_token'],
      });

      if (sessions.length === 0) {
        this.logger.log(
          `sendCallFcmPush: No active sessions/tokens found for user ${userId}`,
        );
        return;
      }

      const mobileSessions = sessions.filter(
        (session) => session.device_name !== 'web',
      );

      if (mobileSessions.length === 0) {
        this.logger.log(
          `sendCallFcmPush: No mobile sessions found for user ${userId}; skipping call push`,
        );
        return;
      }

      const skippedWebSessions = sessions.length - mobileSessions.length;
      if (skippedWebSessions > 0) {
        this.logger.log(
          `sendCallFcmPush: Skipping ${skippedWebSessions} web session(s) for user ${userId}`,
        );
      }

      const invalidTokenSessions = new Map<string, 'fcm' | 'voip'>();
      const fcmSessionsByToken = new Map<string, string[]>();
      const voipSessionsByToken = new Map<string, string[]>();

      for (const session of mobileSessions) {
        if (session.fcm_token) {
          const sessionIds = fcmSessionsByToken.get(session.fcm_token) ?? [];
          sessionIds.push(session.id);
          fcmSessionsByToken.set(session.fcm_token, sessionIds);
        }

        if (session.voip_token) {
          const sessionIds = voipSessionsByToken.get(session.voip_token) ?? [];
          sessionIds.push(session.id);
          voipSessionsByToken.set(session.voip_token, sessionIds);
        }
      }

      const rememberInvalidSessions = (
        sessionIds: string[],
        tokenType: 'fcm' | 'voip',
      ) => {
        for (const sessionId of sessionIds) {
          invalidTokenSessions.set(sessionId, tokenType);
        }
      };

      const pushPromises: Promise<void>[] = [];

      // 1. Send VoIP Push via APNS (priority for iOS CallKit)
      for (const [token, sessionIds] of voipSessionsByToken.entries()) {
        const isVideo = data.call_type === 'video' || data.type === 'video';
        const voipPayload = {
          id: data.call_id,
          nameCaller: data.caller_name || 'Người gọi',
          handle: data.caller_name || 'Người gọi',
          type: isVideo ? 1 : 0,
          duration: 45000,
          extra: data,
          ios: {
            ringtonePath: 'ringtone.mp3',
          },
        };
        this.logger.log(
          `sendCallFcmPush: Sending VoIP Push via APNS to user ${userId} (type=${data.type})`,
        );
        pushPromises.push(
          this.apnsService
            .sendVoipPush(token, voipPayload)
            .then((result) => {
              if (
                !result.success &&
                result.badTokens &&
                result.badTokens.length > 0
              ) {
                rememberInvalidSessions(sessionIds, 'voip');
              }
            })
            .catch((err) =>
              this.logger.error(`APNS VoIP Push failed: ${err.message}`),
            ),
        );
      }

      // 2. Send Call Signaling via FCM (fallback and Android)
      for (const [token, sessionIds] of fcmSessionsByToken.entries()) {
        this.logger.log(
          `sendCallFcmPush: Sending Call Push via FCM to user ${userId} (type=${data.type})`,
        );
        pushPromises.push(
          this.firebaseService
            .sendCallPush(token, data)
            .then((result) => {
              if (!result.success && result.shouldRemoveToken) {
                rememberInvalidSessions(sessionIds, 'fcm');
              }
            })
            .catch((err) =>
              this.logger.error(`FCM Call Push failed: ${err.message}`),
            ),
        );
      }

      await Promise.all(pushPromises);

      // Clean up invalid tokens
      for (const [sessionId, tokenType] of invalidTokenSessions.entries()) {
        try {
          const updateData =
            tokenType === 'fcm' ? { fcm_token: null } : { voip_token: null };
          await this.sessionRepo.update(sessionId, updateData);
          this.logger.log(
            `Removed invalid ${tokenType} token for session ${sessionId}`,
          );
        } catch (err: any) {
          this.logger.error(
            `Failed to remove invalid ${tokenType} token: ${err.message}`,
          );
        }
      }
    } catch (err: any) {
      this.logger.error(`Failed to send call push: ${err.message}`);
    }
  }
}
