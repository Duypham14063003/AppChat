import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private initialized = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      this.logger.warn(
        'FIREBASE_PROJECT_ID not set — push notifications disabled',
      );
      return;
    }

    try {
      const serviceAccountKey = this.config.get<string>(
        'FIREBASE_SERVICE_ACCOUNT_KEY',
      );
      const credential = serviceAccountKey
        ? admin.credential.cert(JSON.parse(serviceAccountKey))
        : admin.credential.applicationDefault();

      admin.initializeApp({ credential, projectId });
      this.initialized = true;
      this.logger.log('Firebase Admin SDK initialized');
    } catch (err: any) {
      this.logger.error(`Firebase init failed: ${err.message}`);
    }
  }

  async sendPush(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    badgeCount = 1,
  ): Promise<boolean> {
    if (!this.initialized) return false;

    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default', badge: badgeCount } } },
      });
      return true;
    } catch (err: any) {
      if (err.code === 'messaging/registration-token-not-registered') {
        this.logger.warn(`Invalid FCM token: ${token.substring(0, 10)}...`);
        return false;
      }
      this.logger.error(`FCM send failed: ${err.message}`);
      return false;
    }
  }

  isEnabled(): boolean {
    return this.initialized;
  }
}
