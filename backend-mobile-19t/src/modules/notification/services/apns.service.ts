import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as apnRaw from '@parse/node-apn';
import * as fs from 'fs';
import * as path from 'path';

const apn = apnRaw as any;

@Injectable()
export class ApnsService implements OnModuleInit {
  private readonly logger = new Logger(ApnsService.name);
  private provider: any = null;
  private bundleId = '';
  private isProduction = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const pfxPath = this.config.get<string>('APNS_VOIP_PFX_PATH');
    if (!pfxPath) {
      this.logger.warn(
        'APNS_VOIP_PFX_PATH not set — APNs VoIP push notifications disabled',
      );
      return;
    }

    const absolutePath = path.isAbsolute(pfxPath)
      ? pfxPath
      : path.join(process.cwd(), pfxPath);

    if (!fs.existsSync(absolutePath)) {
      this.logger.error(`APNs certificate file not found at: ${absolutePath}`);
      return;
    }

    const passphrase = this.config.get<string>('APNS_VOIP_PASSPHRASE');
    const isProduction =
      this.config.get<string>('APNS_IS_PRODUCTION') === 'true';
    this.isProduction = isProduction;
    let bundleId = this.config.get<string>(
      'APNS_VOIP_BUNDLE_ID',
      'vn.19t.nineteenTechApp.voip',
    );
    if (!bundleId.endsWith('.voip')) {
      bundleId = `${bundleId}.voip`;
    }
    this.bundleId = bundleId;

    try {
      this.provider = new apn.Provider({
        pfx: fs.readFileSync(absolutePath),
        passphrase: passphrase || undefined,
        production: isProduction,
      });
      this.logger.log(
        `APNs Provider initialized for bundle ID: ${this.bundleId} (${isProduction ? 'Production' : 'Sandbox'})`,
      );
    } catch (err: any) {
      this.logger.error(`Failed to initialize APNs Provider: ${err.message}`);
    }
  }

  async sendVoipPush(
    token: string,
    data: Record<string, any>,
  ): Promise<{ success: boolean; badTokens?: string[] }> {
    if (!this.provider) {
      this.logger.warn('APNs Provider not initialized, skipping push.');
      return { success: false };
    }

    try {
      const note = new apn.Notification();
      note.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
      note.priority = 10;
      note.pushType = 'voip';
      note.topic = this.bundleId;
      note.payload = data;

      const result = await this.provider.send(note, token);
      if (result.sent.length > 0) {
        return { success: true };
      }

      const badTokens: string[] = [];
      if (result.failed.length > 0) {
        for (const failure of result.failed) {
          this.logger.error(
            `APNs VoIP push failed for token ${token.substring(0, 10)}... | Topic: ${this.bundleId} | Production: ${this.isProduction} | Failure: ${JSON.stringify(failure)}`,
          );

          // Check for bad device token
          if (
            failure.response?.reason === 'BadDeviceToken' ||
            failure.error?.reason === 'BadDeviceToken'
          ) {
            badTokens.push(token);
          }
        }
      }

      return { success: false, badTokens };
    } catch (err: any) {
      this.logger.error(`Failed to send APNs VoIP push: ${err.message}`);
      return { success: false };
    }
  }
}
