# 8.4 Risk Matrix (FMEA)

## Risk Priority Number (RPN) = Severity × Occurrence × Detection

- Severity (1-10): Mức độ nghiêm trọng nếu xảy ra
- Occurrence (1-10): Khả năng xảy ra
- Detection (1-10): Khả năng phát hiện trước khi ảnh hưởng user (10 = khó phát hiện)

## Technical Risks

| # | Risk | Severity | Occurrence | Detection | RPN | Mitigation |
|---|------|----------|------------|-----------|-----|------------|
| T1 | Message mất khi server restart | 9 | 3 | 4 | 108 | BullMQ persistent queue + Redis AOF + client retry |
| T2 | WebSocket connection drop không detect | 7 | 5 | 3 | 105 | Heartbeat ping/pong mỗi 30s + reconnect logic |
| T3 | PostgreSQL slow query khi data lớn | 6 | 4 | 3 | 72 | Partition by quarter + proper indexes + EXPLAIN ANALYZE |
| T4 | Agora SDK crash trên platform cụ thể | 7 | 3 | 5 | 105 | Test trên tất cả platforms + Agora error handling + fallback UI |
| T5 | JWT token theft | 9 | 2 | 6 | 108 | Refresh token rotation + secure storage + token theft detection |
| T6 | Odoo API down ảnh hưởng app | 5 | 4 | 2 | 40 | Circuit breaker + batch sync + graceful degradation |
| T7 | File upload fail (Bunny.net) | 4 | 3 | 2 | 24 | Retry logic + progress indicator + error message |
| T8 | FCM push không tới (iOS background) | 6 | 4 | 5 | 120 | VoIP push cho calls + delta sync khi foreground |
| T9 | Drift local DB corrupt | 7 | 2 | 6 | 84 | DB integrity check on start + re-sync from server |
| T10 | Memory leak Flutter chat screen | 5 | 4 | 4 | 80 | RepaintBoundary + dispose controllers + profiling |

## Business Risks

| # | Risk | Severity | Occurrence | Detection | RPN | Mitigation |
|---|------|----------|------------|-----------|-----|------------|
| B1 | HR tính công sai → ảnh hưởng lương | 10 | 3 | 3 | 90 | Unit test 100% coverage + manual verification kỳ đầu |
| B2 | User không chịu dùng app mới | 6 | 4 | 3 | 72 | Pilot 5 người → feedback → iterate → rollout dần |
| B3 | Scope creep → không ship được | 7 | 5 | 2 | 70 | Strict MVP scope + phase-based delivery |
| B4 | Odoo API thay đổi breaking | 6 | 2 | 5 | 60 | API versioning + adapter pattern + monitoring |
| B5 | Data migration từ tools cũ fail | 5 | 3 | 4 | 60 | ETL script + dry run + rollback plan |

## Security Risks

| # | Risk | Severity | Occurrence | Detection | RPN | Mitigation |
|---|------|----------|------------|-----------|-----|------------|
| S1 | Unauthorized access to HR data | 9 | 2 | 4 | 72 | RBAC + API guards + audit logging |
| S2 | SQL injection | 9 | 1 | 2 | 18 | TypeORM parameterized queries + input validation |
| S3 | XSS trong chat messages | 7 | 3 | 3 | 63 | Sanitize input + escape output |
| S4 | Brute force login | 6 | 3 | 2 | 36 | Rate limiting 5/15min + account lockout |
| S5 | Sensitive data in logs | 7 | 3 | 5 | 105 | Log sanitization + no PII in logs |

## RPN Thresholds

| RPN Range | Action Required |
|-----------|----------------|
| > 100 | 🔴 Phải giải quyết trước khi release |
| 60-100 | 🟠 Cần mitigation plan, giải quyết trong sprint |
| 30-59 | 🟡 Monitor, giải quyết khi có thời gian |
| < 30 | 🟢 Acceptable risk |

## Top 5 Risks cần ưu tiên (RPN > 100)

1. **T8 (RPN 120)** — FCM push không tới iOS background → VoIP push + delta sync
2. **T1 (RPN 108)** — Message mất khi restart → BullMQ persistent + client retry
3. **T5 (RPN 108)** — JWT token theft → rotation + detection
4. **T2 (RPN 105)** — WS drop không detect → heartbeat + reconnect
5. **T4 (RPN 105)** — Agora crash → error handling + fallback
6. **S5 (RPN 105)** — Sensitive data in logs → sanitization

