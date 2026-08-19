## ADDED Requirements

### Requirement: System messages for group lifecycle events
The system SHALL generate messages with type `system` for the following group events. System messages have `sender_id` set to the actor (user who performed the action). The `content` field stores the action key. The `metadata` JSONB field stores structured data for rendering.

| Event | content | metadata |
|-------|---------|----------|
| Group created | `created_group` | `{ action, actor_name, group_name }` |
| Member added | `added_member` | `{ action, actor_name, member_name, member_id }` |
| Member removed | `removed_member` | `{ action, actor_name, member_name, member_id }` |
| Member left | `left_group` | `{ action, actor_name }` |
| Group renamed | `renamed_group` | `{ action, actor_name, old_name, new_name }` |
| Group avatar changed | `changed_avatar` | `{ action, actor_name }` |

#### Scenario: System message inserted on member add
- **WHEN** admin "Nguyen Van A" adds "Tran Van B" to the group
- **THEN** a message is inserted with type=system, sender_id=admin's ID, content="added_member", metadata=`{ action: "added_member", actor_name: "Nguyen Van A", member_name: "Tran Van B", member_id: "<id>" }`

#### Scenario: System message inserted on member leave
- **WHEN** "Tran Van B" leaves the group
- **THEN** a message is inserted with type=system, sender_id=B's ID, content="left_group", metadata=`{ action: "left_group", actor_name: "Tran Van B" }`

### Requirement: Flutter renders system messages distinctly
The Flutter chat screen SHALL render system messages as centered, non-bubble text with secondary styling. The message content key SHALL be mapped to a Vietnamese display string using the metadata fields.

| content key | Display format |
|-------------|---------------|
| `created_group` | `{actor_name} đã tạo nhóm` |
| `added_member` | `{actor_name} đã thêm {member_name}` |
| `removed_member` | `{actor_name} đã xóa {member_name}` |
| `left_group` | `{actor_name} đã rời nhóm` |
| `renamed_group` | `{actor_name} đã đổi tên nhóm thành «{new_name}»` |
| `changed_avatar` | `{actor_name} đã đổi ảnh nhóm` |

#### Scenario: System message displayed in chat
- **WHEN** a system message with content="added_member" is rendered
- **THEN** it appears as centered text: "Nguyen Van A đã thêm Tran Van B" with secondary text color, no bubble

### Requirement: System messages are published via Redis Pub/Sub
System messages SHALL be published to the conversation's Redis Pub/Sub channel just like regular messages, so all online members receive them in real-time. They SHALL also update the conversation's `last_message_at` timestamp.

#### Scenario: Online members see system message in real-time
- **WHEN** a system message is generated (e.g., member added)
- **THEN** all online members of the conversation receive it via WebSocket as a `new_message` event

