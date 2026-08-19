# PoC and Demo Coordination Operations

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `POC_REPORT_CONVERSATION_ID` | `35353995-517b-4fcb-b4d7-e0f23c5f4042` | Weekly summary conversation |
| `POC_REPORT_TIME` | `12:00` | Friday publication time |
| `POC_TIMEZONE` | `Asia/Ho_Chi_Minh` | ISO week and scheduler timezone |
| `POC_DAILY_CAPACITY_HOURS` | `8` | Fixed planned daily capacity |
| `POC_WEEKLY_CAPACITY_HOURS` | `40` | Fixed planned weekly capacity |
| `POC_REMINDER_OFFSETS_MINUTES` | `1440,30` | Reminder offsets before `demo_at` |

PoC capacity is planned capacity from PoC estimates only. It is not actual
timesheet, attendance, or Odoo task utilization. Approved leave is displayed
as context in the client but does not change the fixed MVP capacity totals.

## Deployment

1. Confirm PostgreSQL and Redis are reachable from the backend.
2. Back up the target database.
3. Run `npm run typeorm -- migration:show -d data-source.ts` and confirm only
   the intended migrations are pending.
4. Run `npm run migration:run` once during the deployment window.
5. Deploy the backend with both API and BullMQ worker/scheduler providers
   enabled through `PocModule`.
6. Deploy the Flutter client after the API is available.
7. Use `POST /pocs/weekly-report/publish?week=<ISO_DATE>` to recover or refresh
   the weekly message if the scheduled publication failed.

Do not place Jest `*.spec.ts` files in the TypeORM migration glob. The current
`data-source.ts` explicitly excludes them.

## Monitoring

- Monitor the `poc-coordination` BullMQ queue for failed `poc-notification`,
  `publish-weekly-report`, and `refresh-weekly-report` jobs.
- Query `poc_notification_events` for `status = 'failed'`, increasing
  `attempts`, and `last_error`.
- Query `poc_weekly_reports` for `status = 'failed'` or a missing
  `chat_message_id` after Friday 12:00 ICT.
- Application logs include PoC IDs for chat projection and delivery failures.
- Weekly refresh edits the stored system message. Multiple weekly messages for
  the same ISO week indicate an operational or data integrity issue.

## Rollback

1. Stop the backend workers to prevent new PoC jobs during rollback.
2. Revert the client and backend application versions.
3. If no production PoC data must be retained, run
   `npm run migration:revert` to remove the PoC tables and sequence.
4. If PoC records already exist, preserve the tables and deploy a compatible
   backend instead of reverting the migration.
5. Existing chat system messages are projections and may remain; they do not
   own PoC state.
