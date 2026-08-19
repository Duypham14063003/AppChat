## 1. Backend Fan-out Correction

- [x] 1.1 Update chat conversation fan-out to suppress `new_message` self-echo only for the originating websocket instead of every socket owned by `senderId`.
- [x] 1.2 Preserve existing realtime delivery for other conversation members and same-account secondary devices without changing the client send payload contract.

## 2. Automated Coverage

- [x] 2.1 Add backend coverage for two active sockets under the same `userId`, verifying the non-origin socket receives `new_message`.
- [x] 2.2 Add backend coverage verifying the originating socket still relies on the existing ACK/status path and does not receive a duplicate `new_message` self-echo.

## 3. End-to-End Verification

- [ ] 3.1 Verify an account sending from phone updates the same account on desktop in real time without manual refresh.
- [ ] 3.2 Verify an account sending from desktop updates the same account on phone in real time without manual refresh.
- [ ] 3.3 Verify other conversation members continue receiving realtime messages normally while the sender's origin device does not show duplicate message insertion.
