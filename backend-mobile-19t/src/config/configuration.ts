import * as Joi from 'joi';

export const validationSchema = Joi.object({
  // PostgreSQL
  DB_HOST: Joi.string().required(),
  DB_PORT: Joi.number().default(5432),
  DB_USER: Joi.string().required(),
  DB_NAME: Joi.string().required(),
  DB_PASSWORD: Joi.string().required(),

  // Redis
  REDIS_HOST: Joi.string().required(),
  REDIS_PORT: Joi.number().default(6379),

  // NestJS
  PORT: Joi.number().default(3000),
  CORS_ORIGINS: Joi.string().optional().allow(''),

  // JWT
  JWT_ACCESS_SECRET: Joi.string().required(),
  JWT_REFRESH_SECRET: Joi.string().required(),
  JWT_ACCESS_TTL: Joi.string().default('15m'),
  JWT_REFRESH_TTL: Joi.string().default('30d'),

  BOT_API_KEY: Joi.string().optional().allow(''),

  // Optional — production services
  ODOO_URL: Joi.string().uri().optional().allow(''),
  ODOO_DB: Joi.string().optional().allow(''),
  ODOO_API_KEY: Joi.string().optional().allow(''),
  ODOO_SERVICE_USERNAME: Joi.string().optional().allow(''),
  ODOO_SERVICE_PASSWORD: Joi.string().optional().allow(''),

  FIREBASE_PROJECT_ID: Joi.string().optional().allow(''),
  FIREBASE_SERVICE_ACCOUNT_KEY: Joi.string().optional().allow(''),

  AGORA_APP_ID: Joi.string().optional().allow(''),
  AGORA_APP_CERTIFICATE: Joi.string().optional().allow(''),

  BUNNY_STORAGE_ZONE: Joi.string().optional().allow(''),
  BUNNY_STORAGE_API_KEY: Joi.string().optional().allow(''),
  BUNNY_CDN_URL: Joi.string().optional().allow(''),

  AI_PROVIDER: Joi.string().valid('openai', 'anthropic').default('openai'),
  AI_BASE_URL: Joi.string().uri().optional().allow(''),
  AI_API_KEY: Joi.string().optional().allow(''),
  AI_MODEL: Joi.string().default('gpt-4o'),

  APNS_VOIP_PFX_PATH: Joi.string().optional().allow(''),
  APNS_VOIP_PASSPHRASE: Joi.string().optional().allow(''),
  APNS_VOIP_BUNDLE_ID: Joi.string().optional().allow(''),
  APNS_IS_PRODUCTION: Joi.boolean().default(false),

  // PoC coordination
  POC_REPORT_CONVERSATION_ID: Joi.string()
    .uuid()
    .default('35353995-517b-4fcb-b4d7-e0f23c5f4042'),
  POC_REPORT_TIME: Joi.string()
    .pattern(/^([01]\d|2[0-3]):[0-5]\d$/)
    .default('12:00'),
  POC_TIMEZONE: Joi.string().default('Asia/Ho_Chi_Minh'),
  POC_DAILY_CAPACITY_HOURS: Joi.number().positive().default(8),
  POC_WEEKLY_CAPACITY_HOURS: Joi.number().positive().default(40),
  POC_REMINDER_OFFSETS_MINUTES: Joi.string().default('1440,30'),
});
