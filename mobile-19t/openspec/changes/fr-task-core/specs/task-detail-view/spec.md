## ADDED Requirements

### Requirement: Task detail screen
The system SHALL provide a TaskDetailScreen showing full task information: task name (large title), stage badge (colored), deadline (with overdue indicator), priority stars, assignee names with avatars, and description (rendered from plain text or HTML).

#### Scenario: View task detail
- **WHEN** the user taps a task in the list
- **THEN** the TaskDetailScreen shows all task fields from Odoo

### Requirement: Task metadata display
The system SHALL display task metadata in a structured layout: stage as a colored badge, deadline as formatted date with relative indicator ("2 ngày nữa" or "Quá hạn 3 ngày"), priority as stars (★★★ Cao / ★★☆ Trung bình / ★☆☆ Thấp), assignees as avatar row with names.

#### Scenario: Task with high priority and upcoming deadline
- **WHEN** a task has priority "high" and deadline in 2 days
- **THEN** the detail shows ★★★ in danger color and deadline with "2 ngày nữa" in warning color

### Requirement: Log notes list in task detail
The system SHALL display a list of log notes (comments) below the task metadata, ordered by date descending (newest first). Each log note SHALL show: author name, date (relative format), and body content. HTML body content SHALL be rendered as styled text (strip tags or use flutter_html).

#### Scenario: View log notes
- **WHEN** a task has 5 log notes
- **THEN** all 5 are displayed below the task description with author, date, and content

#### Scenario: No log notes
- **WHEN** a task has no log notes
- **THEN** an empty state message "Chưa có ghi chú" is shown

### Requirement: Write log note from task detail
The system SHALL provide a text input at the bottom of the TaskDetailScreen for writing new log notes. The input SHALL have a send button. On submit, the system SHALL POST the log note to Odoo via the REST API and append it to the log notes list optimistically.

#### Scenario: Submit log note
- **WHEN** the user types "Đã hoàn thành phần API" and taps send
- **THEN** the log note is sent to Odoo, appears immediately in the list, and a success indicator is shown

#### Scenario: Log note write failure
- **WHEN** the user submits a log note but Odoo is unreachable
- **THEN** an error SnackBar "Không thể gửi ghi chú. Vui lòng thử lại." is shown and the optimistic entry is removed

### Requirement: Log note input bar design
The log note input SHALL follow the same visual pattern as the chat MessageInputBar: `AppColors.surface` background, top border, rounded text field with `AppColors.surfaceVariant` fill, gold send icon button. Placeholder text: "Nhập ghi chú..."

#### Scenario: Input bar appearance
- **WHEN** the TaskDetailScreen is displayed
- **THEN** a log note input bar is visible at the bottom matching the chat input bar style

### Requirement: Responsive task detail on web
On wide screens (≥768px), the TaskDetailScreen SHALL be displayed as the right panel in the master-detail layout, filling the remaining space after the project sidebar and task list. The log note input SHALL be fixed at the bottom of the detail panel.

#### Scenario: Wide screen detail panel
- **WHEN** the user selects a task on a wide screen
- **THEN** the detail fills the right panel with log note input at the bottom

