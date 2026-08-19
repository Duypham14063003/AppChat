 Plan: Verify WebSocket + E2E Messaging & Update README                                                                                                   │
│                                                                                                                                                          │
│ Context                                                                                                                                                  │
│                                                                                                                                                          │
│ Chat module migrations đã chạy thành công. Cần verify WebSocket connect/auth/heartbeat và end-to-end messaging hoạt động, sau đó update README với hướng │
│  dẫn test.                                                                                                                                               │
│                                                                                                                                                          │
│ Approach                                                                                                                                                 │
│                                                                                                                                                          │
│ 1. Create test script apps/api/test/ws-test.ts                                                                                                           │
│                                                                                                                                                          │
│ Script dùng ws + axios (đã có trong dependencies) để:                                                                                                    │
│ - POST /auth/login với Odoo credentials → lấy JWT                                                                                                        │
│ - Connect WebSocket tới ws://host:port/ws                                                                                                                │
│ - Send auth message { event: "auth", data: { token } }                                                                                                   │
│ - Wait for auth_success                                                                                                                                  │
│ - Listen for heartbeat ping/pong                                                                                                                         │
│ - Send send_message event → wait for message_ack                                                                                                         │
│ - Open 2nd WS connection (simulate recipient) → verify new_message fan-out                                                                               │
│                                                                                                                                                          │
│ Script sẽ nhận credentials từ CLI args hoặc env vars.                                                                                                    │
│                                                                                                                                                          │
│ 2. Add npm script                                                                                                                                        │
│                                                                                                                                                          │
│ "test:ws": "tsx test/ws-test.ts"                                                                                                                         │
│                                                                                                                                                          │
│ 3. Run the test                                                                                                                                          │
│                                                                                                                                                          │
│ Start server (npm run start:dev) in background, run test script, verify output.                                                                          │
│                                                                                                                                                          │
│ Note: Cần real Odoo account (auth 100% qua Odoo SSO). Sẽ hỏi user credentials hoặc tạo script để user tự chạy.                                           │
│                                                                                                                                                          │
│ 4. Update README                                                                                                                                         │
│                                                                                                                                                          │
│ Thêm section "Testing WebSocket & Messaging" vào README với:                                                                                             │
│ - Cách start server                                                                                                                                      │
│ - Cách chạy test script                                                                                                                                  │
│ - Manual test steps với wscat                                                                                                                            │
│                                                                                                                                                          │
│ Files to create/modify                                                                                                                                   │
│                                                                                                                                                          │
│ - apps/api/test/ws-test.ts (new) — test script                                                                                                           │
│ - apps/api/package.json — add test:ws script                                                                                                             │
│ - README.md — add testing instructions                                                                                                                   │
│                                                                                                                                                          │
│ Verification                                                                                                                                             │
│                                                                                                                                                          │
│ - Build passes: npm run build ✓ (already confirmed)                                                                                                      │
│ - Test script connects, authenticates, sends/receives messages                                                                                           │
│ - README has clear instructions
