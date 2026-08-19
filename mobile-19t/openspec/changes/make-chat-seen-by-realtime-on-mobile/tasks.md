## 1. Websocket-driven seen-by refresh

- [x] 1.1 Confirm the mobile websocket layer can receive the production read-receipt event shape used for seen progress updates.
- [x] 1.2 Update chat state management to listen for read-receipt websocket events while a conversation is active.
- [x] 1.3 Invalidate seen-by providers only when the read-receipt event targets the currently open conversation.

## 2. Seen-by state recomputation

- [x] 2.1 Refactor seen-by provider invalidation so message-level and placement-level seen state refresh from the backend after relevant read activity.
- [x] 2.2 Ensure seen-by placement logic still assigns each reader to only the newest visible message they have read.
- [x] 2.3 Preserve exclusion of the currently signed-in user from displayed seen-by avatar rows.

## 3. UI behavior and resilience

- [x] 3.1 Update message-row seen-by rendering so realtime refresh does not break chat list stability during refetch.
- [x] 3.2 Keep seen-by detail sheets opening from current backend data and verify mapped empty/error states still behave correctly.
- [x] 3.3 Verify the active conversation does not refresh seen-by UI in response to unrelated conversation read events.

## 4. Validation

- [ ] 4.1 Test with multiple clients in the same conversation to verify seen-by avatars update without leaving the chat screen.
- [ ] 4.2 Test seen-by detail sheet refresh behavior after another participant reads new messages.
- [x] 4.3 Run the project’s relevant static analysis and regression checks for the mobile chat module.
