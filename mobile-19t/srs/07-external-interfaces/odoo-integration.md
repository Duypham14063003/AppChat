# 7.2 Odoo Integration

## 7.2.1 Connection Info

| Config | Value |
|--------|-------|
| URL | https://erp.19t.vn |
| Database | erp_oddo |
| Service Account | meeting-service@19t.vn |
| Auth method | API Key + Session-based |

## 7.2.2 Odoo APIs Used

### Authentication

```
POST https://erp.19t.vn/web/session/authenticate
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "params": {
    "db": "erp_oddo",
    "login": "{user_email}",
    "password": "{user_password}"
  }
}

Response: { "result": { "uid": 42, "session_id": "...", "name": "Nguyễn Văn A", ... } }
```

### Read Employee Data (Service Account)

```
POST https://erp.19t.vn/jsonrpc
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": ["erp_oddo", uid, api_key,
      "hr.employee", "search_read",
      [[["active", "=", true]]],
      {"fields": ["name", "work_email", "department_id", "job_title", "image_128"]}
    ]
  }
}
```

### Write Attendance (Service Account)

```
POST https://erp.19t.vn/jsonrpc
{
  "jsonrpc": "2.0",
  "method": "call",
  "params": {
    "service": "object",
    "method": "execute_kw",
    "args": ["erp_oddo", uid, api_key,
      "hr.attendance", "create",
      [{"employee_id": 42, "check_in": "2026-03-15 08:00:00"}]
    ]
  }
}
```

### Read Projects & Tasks

```
// Projects
"project.project", "search_read", [[]], {"fields": ["name", "user_id", "date_start", "date"]}

// Tasks
"project.task", "search_read",
  [[["project_id", "=", project_id]]],
  {"fields": ["name", "user_ids", "stage_id", "date_deadline", "priority", "description"]}
```

### Write Timesheet

```
"account.analytic.line", "create",
[{"project_id": 1, "task_id": 5, "name": "UI chat", "unit_amount": 4.0, "date": "2026-03-15"}]
```

## 7.2.3 Sync Strategy

| Data | Direction | Method | Frequency |
|------|-----------|--------|-----------|
| User auth | App → Odoo | Real-time (login) | On demand |
| Employee profiles | Odoo → App | BullMQ cron | Every 1 hour |
| Attendance | App → Odoo | BullMQ batch | Every 15 minutes |
| Leave requests | App → Odoo | BullMQ batch | Every 15 minutes |
| Projects | Odoo → App | BullMQ cron | Every 15 minutes |
| Tasks | Odoo → App | BullMQ cron | Every 15 minutes |
| Timesheets | App → Odoo | Real-time (on confirm) | On demand |

## 7.2.4 Error Handling

- Odoo timeout: 10 giây, retry 3 lần với exponential backoff
- Odoo down: queue requests trong BullMQ, retry khi available
- Circuit breaker: sau 5 failures liên tiếp → open circuit 5 phút → half-open → retry
- Odoo rate limit: unknown, implement client-side throttle 10 req/s

