## Summary

Implement Telegram-style message reply for the chat feature — swipe-to-reply gesture, long-press context menu, reply preview above input bar, quoted reply block inside message bubbles, and scroll-to-original on tap. Covers text, image, and album message types in both direct and group conversations.

## Why

The chat module has `reply_to_id` wired end-to-end (DB column, API insert, WS transport, local SQLite column) but zero UI. Users cannot reply to specific messages — a fundamental chat interaction. The SRS defines this as CHAT-FR-010 (P0 MUST). All backend plumbing exists; this change is primarily Flutter UI + a small API enhancement to eager-load replied message data.

## What Changes

### Flutter (apps/mobile)
- **Swipe-to-reply gesture** on message bubbles with haptic feedback and animated reply icon
- **Long-press context menu** (bottom sheet) with "Trả lời" (Reply) action
- **Reply preview bar** above MessageInputBar showing sender name, content preview, close button
- **Quoted reply block** inside MessageBubble showing original message sender + content preview with gold left accent bar
- **Scroll-to-original** when tapping quoted reply block — scroll to original message + highlight animation
- **sendMessage / sendImageMessage** updated to include `reply_to_id` in WS payload

### API (apps/api)
- **getMessages()** enhanced to eager-load `reply_to` data (id, sender_id, sender_name, content, type) for messages that have `reply_to_id`

## Capabilities

| ID | Name | Description |
|----|------|-------------|
| swipe-and-context-menu | Swipe & Context Menu | Swipe-right gesture + long-press bottom sheet to trigger reply |
| reply-input-preview | Reply Input Preview | Reply preview bar above input with sender name, content, close button |
| quoted-reply-bubble | Quoted Reply Bubble | Quoted reply block in message bubble + tap to scroll to original |
| api-reply-data | API Reply Data | Eager-load reply_to message data in getMessages response |

## Impact

- **Schema changes**: None — `reply_to_id` column already exists in both PostgreSQL and SQLite
- **New packages**: None required (custom gesture implementation)
- **Migration**: None
- **Breaking changes**: None — API response gains optional `reply_to` field (additive)
