import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { WsAdapter } from '@nestjs/platform-ws';
import type { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import { AppModule } from './app.module';

function parseCorsOrigins(rawOrigins?: string): string[] {
  if (!rawOrigins) {
    return [];
  }

  return rawOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  app.useWebSocketAdapter(new WsAdapter(app));

  app.setGlobalPrefix('/api/v1');
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  const corsOrigins = parseCorsOrigins(
    configService.get<string>('CORS_ORIGINS'),
  );
  const defaultAllowedHeaders = [
    'Origin',
    'X-Requested-With',
    'Content-Type',
    'Accept',
    'Authorization',
  ];
  const allowedMethods = 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS';

  app.use((req: Request, res: Response, next: NextFunction) => {
    const requestOrigin = req.headers.origin;
    const matchedOrigin =
      corsOrigins.length === 0
        ? requestOrigin || '*'
        : requestOrigin && corsOrigins.includes(requestOrigin)
          ? requestOrigin
          : corsOrigins[0];
    const requestedHeaders = req.headers['access-control-request-headers'];

    res.header('Vary', 'Origin, Access-Control-Request-Headers');
    res.header('Access-Control-Allow-Origin', matchedOrigin);
    res.header('Access-Control-Allow-Methods', allowedMethods);
    res.header(
      'Access-Control-Allow-Headers',
      typeof requestedHeaders === 'string' && requestedHeaders.trim().length > 0
        ? requestedHeaders
        : defaultAllowedHeaders.join(','),
    );
    res.header('Access-Control-Allow-Credentials', 'true');

    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }

    next();
  });

  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: defaultAllowedHeaders,
    credentials: true,
    optionsSuccessStatus: 204,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('Nineteen Tech Internal API')
    .setDescription('API for Nineteen Tech Internal App')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('/api/docs', app, document);

  const port = Number(process.env.PORT || 3000);
  const host = '0.0.0.0';
  const appUrl = process.env.APP_URL || `http://localhost:${port}`;
  const normalizedAppUrl = appUrl.replace(/\/+$/, '');

  await app.listen(port, host);

  logger.log(`Base URL: ${normalizedAppUrl}`);
  logger.log(`API URL: ${normalizedAppUrl}/api/v1`);
  logger.log(`Swagger URL: ${normalizedAppUrl}/api/docs`);
}
void bootstrap();
