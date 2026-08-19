import { config } from 'dotenv';
import * as path from 'path';
import { DataSource } from 'typeorm';

config({ path: path.resolve(__dirname, '.env') });

export default new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USER || 'app_19t',
  password: process.env.DB_PASSWORD || 'local_dev_password',
  database: process.env.DB_NAME || 'app_19t_dev',
  entities: [path.join(__dirname, 'src/modules/**/entities/*.entity.{ts,js}')],
  migrations: [path.join(__dirname, 'src/migrations/*.{ts,js}')],
  synchronize: false,
});

