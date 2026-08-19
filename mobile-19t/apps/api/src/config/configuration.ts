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

  // JWT
  JWT_ACCESS_SECRET: Joi.string().required(),
  JWT_REFRESH_SECRET: Joi.string().required(),
  JWT_ACCESS_TTL: Joi.string().default('15m'),
  JWT_REFRESH_TTL: Joi.string().default('30d'),

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
});
