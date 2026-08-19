## Context

The backend already has an organization-level daily contract reminder job that scans active employee contracts with an `end_date`, prevents duplicate delivery through `contract_reminder_events`, and sends FCM pushes. The current implementation treats reminders as generic expiry warnings and includes a recipient filter that can match `admin`, `manager`, or an internal HR role id.

The business rule is more specific: internship and probation contracts should trigger an official-contract proposal reminder one week before the contract ends, while official contracts should trigger a renewal proposal reminder ten days before expiry. Recipients must be limited to active users whose role name is `admin` or `manager`.

## Goals / Non-Goals

**Goals:**
- Keep the existing daily contract reminder scheduler and duplicate prevention model.
- Make reminder thresholds and notification semantics explicit by contract type.
- Restrict recipients by role name only: `admin` and `manager`, case-insensitive.
- Provide notification payloads that distinguish official-contract proposal reminders from renewal proposal reminders.
- Add focused backend tests for timing, recipient filtering, payload semantics, and duplicate prevention.

**Non-Goals:**
- Add a new contract workflow, approval table, or task-management object for proposals.
- Notify employees about their own contract action reminders.
- Change payroll reminder scheduling or attendance reminder behavior.
- Add configurable reminder thresholds.

## Decisions

### D1: Reuse the existing daily contract reminder job

The change will keep the current organization-level BullMQ scheduler that runs contract expiry checks once per day in the `Asia/Ho_Chi_Minh` timezone.

Why: The existing scheduler already matches the operational need and avoids adding another background job. The change is primarily about semantics, recipients, and tests.

Alternative considered: Add separate jobs for internship/probation and official reminders. Rejected because both flows scan the same contract table and share duplicate prevention.

### D2: Derive reminder action from contract type

The reminder service will map contract type to an action:

```text
internship, probation -> propose_official_contract, threshold 7 days
official                -> propose_contract_renewal, threshold 10 days
temporary               -> no reminder
```

Why: The action is deterministic from the contract type in the current HR model. Keeping this mapping in the reminder service makes tests straightforward and avoids schema churn.

Alternative considered: Store reminder type per contract. Rejected because there is no current business need for per-contract overrides.

### D3: Filter recipients by role name only

Recipient lookup will include only active users with role names `admin` or `manager`, matched case-insensitively. It will not include users solely through an internal HR role id.

Why: The business requirement explicitly names role names, and role-name filtering is easier for admins to reason about than hidden id-based expansion.

Alternative considered: Keep the internal HR role id fallback. Rejected because it can notify users outside the requested role-name set.

### D4: Use action-specific notification copy and payload

Notifications will keep a contract-related payload but include an action value so mobile can route or present the reminder appropriately.

Suggested payload shape:

```json
{
  "type": "hr_contract_action_reminder",
  "action": "propose_official_contract",
  "contract_id": "...",
  "user_id": "..."
}
```

Why: An explicit action avoids inferring behavior from localized text or contract type after the push is received.

Alternative considered: Keep the existing `hr_contract_expiry` payload only. Rejected because it cannot cleanly distinguish proposal vs renewal actions.

## Risks / Trade-offs

- [Risk] Some existing HR users may currently receive reminders through the internal HR role id but not through role name `admin` or `manager`. -> Mitigation: Document the role-name-only rule and add tests that prevent accidental expansion.
- [Risk] Mobile may not yet route the new payload type. -> Mitigation: Include a task to verify and update notification tap routing to the relevant employee contract context.
- [Risk] Exact-day reminders can be missed if the scheduler is down on the threshold date. -> Mitigation: Keep current exact-day behavior for this change; consider catch-up windows separately if the business asks for reliability beyond existing semantics.
