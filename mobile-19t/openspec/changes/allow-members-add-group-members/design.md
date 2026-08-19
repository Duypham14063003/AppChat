## Context

The current group membership flow already supports add, remove, leave, role change, and delete operations through REST endpoints backed by `ChatService`. The permission split today is:

- `creator` or `admin`: add members, remove other members, rename/update group
- `creator`: change member roles, delete group
- any member: leave group

The mobile `GroupInfoScreen` mirrors those rules by hiding the add-member entry point and remove controls for regular members. The requested behavior changes only the membership-management permission matrix: regular members must be able to add users, while removing other people must become creator-only.

## Goals / Non-Goals

**Goals:**
- Allow any current member of a group conversation to add active users.
- Restrict removal of other members to the group creator.
- Keep self-leave available to all roles.
- Keep mobile UI affordances aligned with backend authorization.
- Add tests that lock the new permission matrix in place.

**Non-Goals:**
- Changing role-management rules.
- Changing group rename/avatar permissions.
- Changing creator-only group deletion behavior.
- Introducing a new role or changing the REST API shape.

## Decisions

### D1: Keep the existing add-members endpoint and change authorization only

**Decision:** Reuse `POST /conversations/:id/members` and change the authorization rule from `creator/admin` to `any existing member`.

**Why:** The request payload, response shape, system-message behavior, and notification fan-out already match the intended workflow. The change is permission logic, not API design.

**Alternatives considered:**
- Add a separate “invite members” endpoint for regular users. Rejected because it would duplicate existing validation and create two paths for the same mutation.
- Gate additions behind admin approval. Rejected because it does not solve the reported bottleneck.

### D2: Make creator the single authority for removing other members

**Decision:** Keep self-removal available for all members, but require `creator` for removing a different user from the group.

**Why:** This matches the requested ownership model while preserving the existing leave-group flow. It also avoids broadening admin power when the new product direction is explicitly creator-owned removal.

**Alternatives considered:**
- Keep `admin` and `creator` both able to remove others. Rejected because it preserves the current pain around unclear authority boundaries.
- Prevent creator self-leave. Rejected because it changes existing semantics and is outside the stated request.

### D3: Split mobile UI permissions into additive and destructive actions

**Decision:** Replace the single “can manage group” assumption in `GroupInfoScreen` with separate capability flags:

- `canAddMembers`: any member
- `canRemoveMembers`: creator only
- existing flags for delete-group and rename/avatar remain unchanged

**Why:** The current UI couples all member-management actions behind one boolean. The new rules need additive and destructive actions to diverge cleanly.

**Alternatives considered:**
- Keep one boolean and patch special cases around it. Rejected because it obscures the new permission model and risks regressions in future UI changes.

### D4: Preserve system messages and notifications for successful additions only

**Decision:** Keep the existing add-member system messages and membership-added notifications unchanged. Removal system messages remain unchanged, but fewer actors will be authorized to trigger them.

**Why:** The business change is about who may perform the action, not how the action is announced.

## Risks / Trade-offs

- **[Members can add the wrong people]** → Mitigation: keep existing active-user validation, duplicate skipping, and conversation membership checks.
- **[UI and backend permissions drift]** → Mitigation: update both service tests and Flutter visibility/action tests for the same role matrix.
- **[Admins lose a destructive capability they previously had]** → Mitigation: preserve creator-only role and delete-group controls so ownership remains explicit and predictable.

## Migration Plan

1. Update backend authorization in `ChatService.addMembers()` and `ChatService.removeMember()`.
2. Update Flutter `GroupInfoScreen` permission flags and action visibility.
3. Add or update backend tests for member-add, creator-remove, and forbidden admin/member removal cases.
4. Add or update Flutter tests for add button visibility and remove control visibility by role.
5. Deploy without API versioning changes because endpoint contracts stay the same.

Rollback: revert the authorization checks and UI visibility rules to the previous `creator/admin` behavior.

## Open Questions

- None for this change. The requested permission matrix is specific enough to implement directly.
