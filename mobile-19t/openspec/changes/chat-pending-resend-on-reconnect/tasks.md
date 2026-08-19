## 1. Offline Queue Lifecycle Bootstrap

- [x] 1.1 Initialize the offline resend queue service during authenticated app lifecycle so reconnect listeners and retry timers are active.
- [x] 1.2 Ensure queue lifecycle is single-instance per session and properly disposed/stopped when user logs out.

## 2. Pending Message Replay Reliability

- [x] 2.1 Update text send flow so immediate WebSocket send failure keeps the message in deterministic retryable `pending` state.
- [x] 2.2 Update offline queue replay logic to resend only retry-safe pending message types and avoid replaying media payloads that require upload finalization.
- [x] 2.3 Keep bounded retry behavior (`retry_count`, max retries, `failed` transition) coherent with ACK-based `sent` transitions.

## 3. Verification

- [x] 3.1 Add mobile tests for disconnect/reconnect auto-resend of pending text messages and ACK status transition to `sent`.
- [x] 3.2 Add coverage ensuring pending image/album/voice/video messages are retried through pending upload flow, not text replay flow.
- [ ] 3.3 Manually verify: send while disconnected, reconnect, and confirm message auto-sends without manual retry; verify max-retry failure path still surfaces.
