## Why

Chat avatars are not visible in the Flutter messaging UI even when users have profile images on the server. This makes the conversation list, contact picker, and related chat surfaces look broken and removes an important identity cue for users.

## What Changes

- Add a Flutter chat avatar display capability that resolves chat avatar URLs into renderable image URLs before they are stored or displayed.
- Ensure direct conversation avatars and group avatars fall back gracefully when the avatar URL is missing or cannot be rendered.
- Apply consistent avatar rendering behavior across chat list and related chat selection/detail surfaces that currently use chat avatar data.

## Capabilities

### New Capabilities
- `flutter-chat-avatar-display`: Ensure chat surfaces render user and group avatars correctly from backend-provided avatar fields, including relative-path avatar URLs.

### Modified Capabilities
- None.

## Impact

- Affected code: Flutter chat providers, conversation/local mapping, and chat UI widgets/screens that render avatars.
- APIs: Existing conversation/member/avatar fields are reused; no backend contract change is required.
- Dependencies: No new backend dependency is expected; the change may introduce a shared Flutter-side avatar URL resolver for chat.
