import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateCallsTable1715100000000 implements MigrationInterface {
  name = 'CreateCallsTable1715100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
        CREATE TYPE "calls_type_enum" AS ENUM('audio', 'video');
        CREATE TYPE "calls_status_enum" AS ENUM('ringing', 'accepted', 'rejected', 'ended', 'missed');
        
        CREATE TABLE "calls" (
            "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
            "caller_id" uuid NOT NULL,
            "receiver_id" uuid NOT NULL,
            "channel_name" varchar NOT NULL,
            "type" "calls_type_enum" NOT NULL DEFAULT 'audio',
            "status" "calls_status_enum" NOT NULL DEFAULT 'ringing',
            "started_at" TIMESTAMP WITH TIME ZONE,
            "accepted_at" TIMESTAMP WITH TIME ZONE,
            "ended_at" TIMESTAMP WITH TIME ZONE,
            "duration" int NOT NULL DEFAULT 0,
            "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
            CONSTRAINT "UQ_calls_channel_name" UNIQUE ("channel_name"),
            CONSTRAINT "PK_calls_id" PRIMARY KEY ("id")
        );

        CREATE INDEX "IDX_calls_caller_id" ON "calls" ("caller_id");
        CREATE INDEX "IDX_calls_receiver_id" ON "calls" ("receiver_id");

        ALTER TABLE "calls" ADD CONSTRAINT "FK_calls_caller_id" FOREIGN KEY ("caller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
        ALTER TABLE "calls" ADD CONSTRAINT "FK_calls_receiver_id" FOREIGN KEY ("receiver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
        ALTER TABLE "calls" DROP CONSTRAINT "FK_calls_receiver_id";
        ALTER TABLE "calls" DROP CONSTRAINT "FK_calls_caller_id";
        DROP INDEX "IDX_calls_receiver_id";
        DROP INDEX "IDX_calls_caller_id";
        DROP TABLE "calls";
        DROP TYPE "calls_status_enum";
        DROP TYPE "calls_type_enum";
    `);
  }
}
