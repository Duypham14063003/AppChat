import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddBotFieldsToUser1716730000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Add bot-related columns to users table
    await queryRunner.query(`
      ALTER TABLE users
      ADD COLUMN is_bot BOOLEAN DEFAULT false NOT NULL,
      ADD COLUMN bot_description TEXT,
      ADD COLUMN bot_webhook_url VARCHAR(500),
      ADD COLUMN bot_created_by UUID;
    `);

    // Create index on is_bot for faster bot queries
    await queryRunner.query(`
      CREATE INDEX idx_users_is_bot ON users(is_bot) WHERE is_bot = true;
    `);

    // Add foreign key constraint for bot_created_by
    await queryRunner.query(`
      ALTER TABLE users
      ADD CONSTRAINT fk_users_bot_created_by
      FOREIGN KEY (bot_created_by) REFERENCES users(id) ON DELETE SET NULL;
    `);

    // Update existing system bot
    await queryRunner.query(`
      UPDATE users
      SET is_bot = true,
          bot_description = 'System Bot'
      WHERE id = '00000000-0000-0000-0000-000000000001';
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop foreign key constraint
    await queryRunner.query(`
      ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_bot_created_by;
    `);

    // Drop index
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_users_is_bot;
    `);

    // Drop columns
    await queryRunner.query(`
      ALTER TABLE users
      DROP COLUMN IF EXISTS bot_created_by,
      DROP COLUMN IF EXISTS bot_webhook_url,
      DROP COLUMN IF EXISTS bot_description,
      DROP COLUMN IF EXISTS is_bot;
    `);
  }
}
