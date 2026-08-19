## 1. Backend Authorization

- [x] 1.1 Update `ChatService.addMembers()` so any existing group member can add active users while keeping duplicate skipping and current notification/system-message behavior.
- [x] 1.2 Update `ChatService.removeMember()` so only the group creator can remove a different user, while self-leave continues to work for all roles.
- [x] 1.3 Review controller error mapping to ensure the changed authorization rules still return the expected HTTP 403 responses.

## 2. Mobile Group Info UI

- [x] 2.1 Refactor `GroupInfoScreen` permission flags so add-member visibility is independent from destructive member-management actions.
- [x] 2.2 Show the add-member action for all current group members and keep remove controls creator-only.
- [x] 2.3 Verify leave-group and creator-only delete-group behavior still matches the updated permission model.

## 3. Verification

- [x] 3.1 Add or update backend tests for member-add success, creator-only removal, forbidden admin removal, forbidden member removal, and self-leave.
- [x] 3.2 Add or update Flutter tests for add-member visibility across roles and creator-only remove controls in the group info screen.
- [x] 3.3 Run the relevant backend and Flutter test suites covering group membership management.
