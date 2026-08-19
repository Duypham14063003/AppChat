import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module.js';
import { AuthService } from '../src/modules/auth/services/auth.service.js';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const authService = app.get(AuthService);

  console.log('Starting Odoo user sync...');
  const result = await authService.syncUsersFromOdoo();
  console.log(`Done: ${result.created} created, ${result.updated} updated, ${result.deactivated} deactivated`);

  await app.close();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
