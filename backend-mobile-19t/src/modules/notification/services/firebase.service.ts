import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private initialized = false;

  constructor(private readonly config: ConfigService) {}

  private isRemovableTokenError(err: any): boolean {
    return (
      err?.code === 'messaging/registration-token-not-registered' ||
      err?.code === 'messaging/invalid-registration-token' ||
      err?.code === 'messaging/mismatched-credential' ||
      err?.message === 'SenderId mismatch'
    );
  }

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

      if (serviceAccountKey) {
        const serviceAccount = JSON.parse(serviceAccountKey);

        // Validate service account has correct project_id
        if (serviceAccount.project_id !== projectId) {
          this.logger.error(
            `Firebase project_id mismatch: service account has "${serviceAccount.project_id}" but config expects "${projectId}"`,
          );
          return;
        }

        // Check if Firebase is already initialized (prevent duplicate init)
        if (!admin.apps.length) {
          const credential = admin.credential.cert(serviceAccount);
          admin.initializeApp({ credential, projectId });
          this.initialized = true;
          this.logger.log('Firebase Admin SDK initialized');
        } else {
          this.initialized = true;
          this.logger.log('Firebase Admin SDK already initialized');
        }
      } else {
        // Use application default credentials
        if (!admin.apps.length) {
          const credential = admin.credential.applicationDefault();
          admin.initializeApp({ credential, projectId });
          this.initialized = true;
          this.logger.log(
            'Firebase Admin SDK initialized with application default credentials',
          );
        } else {
          this.initialized = true;
        }
      }
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
  ): Promise<{ success: boolean; shouldRemoveToken?: boolean }> {
    if (!this.initialized) return { success: false };

    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: { sound: 'default', badge: Math.max(0, badgeCount) },
          },
        },
      });
      return { success: true };
    } catch (err: any) {
      if (this.isRemovableTokenError(err)) {
        this.logger.warn(`Invalid FCM token: ${token.substring(0, 10)}...`);
        return { success: false, shouldRemoveToken: true };
      }
      this.logger.error(`FCM send failed: ${err.message}`);
      // Return false for non-token-related errors, will retry later
      return { success: false };
    }
  }

  async sendCallPush(
    token: string,
    data: Record<string, string>,
  ): Promise<{ success: boolean; shouldRemoveToken?: boolean }> {
    if (!this.initialized) return { success: false };

    try {
      const isInvite = data.type === 'call_invite';
      const payload: any = {
        token,
        data,
        android: { priority: 'high' },
      };

      if (isInvite) {
        payload.apns = {
          payload: {
            aps: {
              'content-available': 1,
              alert: {
                title: data.caller_name || 'Cuộc gọi mới',
                body: 'Bạn có cuộc gọi đến',
              },
            },
          },
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
        };
      } else {
        payload.apns = {
          payload: {
            aps: {
              'content-available': 1,
            },
          },
          headers: {
            'apns-priority': '5',
            'apns-push-type': 'background',
          },
        };
      }

      await admin.messaging().send(payload);
      return { success: true };
    } catch (err: any) {
      if (this.isRemovableTokenError(err)) {
        this.logger.warn(`Invalid FCM token: ${token.substring(0, 10)}...`);
        return { success: false, shouldRemoveToken: true };
      }
      this.logger.error(`FCM send call push failed: ${err.message}`);
      // Return false for non-token-related errors, will retry later
      return { success: false };
    }
  }

  isEnabled(): boolean {
    return this.initialized;
  }
}
