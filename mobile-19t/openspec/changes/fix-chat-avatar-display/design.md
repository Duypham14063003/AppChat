## Context

The Flutter chat module stores avatar values from conversation and member payloads and then passes them directly to `NetworkImage(...)` in multiple UI surfaces. The auth/profile flow already normalizes relative avatar paths into absolute URLs, but the chat flow does not. As a result, chat screens can receive non-null avatar strings that still fail to render, leaving blank avatar circles instead of either the remote image or a meaningful fallback.

The bug is cross-cutting because avatar data is mapped in providers and then consumed by several chat surfaces, including the conversation list and related picker/detail views.

## Goals / Non-Goals

**Goals:**
- Normalize chat avatar URLs consistently before chat UI widgets render them.
- Preserve existing backend contract and rely on existing avatar fields from conversation/member payloads.
- Ensure chat surfaces fall back to initials or icons when no renderable avatar is available.
- Avoid repeated one-off fixes in each widget by centralizing avatar resolution behavior.

**Non-Goals:**
- Changing backend avatar payload shape or API response fields.
- Redesigning chat UI styling.
- Reworking profile upload behavior outside the chat avatar display path.

## Decisions

### 1. Introduce a shared Flutter-side avatar URL resolver for chat

The implementation should use a shared resolver that mirrors the successful auth/profile behavior:
- keep absolute `http://` / `https://` URLs unchanged
- prepend the configured API base URL for relative avatar paths beginning with `/`
- preserve null/empty values as null-like fallbacks

Why this approach:
- It matches already-proven behavior in the auth module
- It fixes the root cause instead of patching individual widgets
- It keeps backend as the source of truth for avatar values while adapting them for Flutter rendering

Alternatives considered:
- Fix each widget individually before calling `NetworkImage`: rejected because it duplicates logic and risks inconsistent behavior
- Require backend to always return absolute URLs: rejected for this change because the current contract is already in use and the bug can be fixed safely in the client

### 2. Resolve avatars at data mapping boundaries, not only at render time

Chat provider mapping should normalize conversation/group/member avatar values before storing them in local conversation records and member maps.

Why this approach:
- All downstream consumers can reuse normalized values
- Existing UI widgets remain simpler and less error-prone
- Local cached chat data becomes immediately usable for all chat surfaces

Alternatives considered:
- Resolve only in widgets: rejected because the same raw values appear in several screens and providers

### 3. Preserve explicit fallback behavior when avatar is absent or fails

Widgets that render avatars should continue to show initials/icons when no avatar is available, and should avoid the “blank circle” state caused by non-null but unusable avatar values.

Why this approach:
- It protects the UI even if some data still arrives incomplete
- It improves user trust and keeps identity cues visible

Alternatives considered:
- Show empty avatar placeholders on all failures: rejected because that is the current broken experience

## Risks / Trade-offs

- [Resolver behavior differs from backend expectations] → Mitigation: mirror the existing auth/profile URL resolution rules instead of inventing a new format.
- [Some chat surfaces remain inconsistent] → Mitigation: inventory all chat widgets/screens using avatar fields and apply the shared resolver/fallback strategy uniformly.
- [Cached local data may contain legacy raw paths] → Mitigation: refresh/re-map conversations through the normalized provider path so newly synced data becomes renderable.

## Migration Plan

1. Add the shared chat avatar resolver.
2. Update chat provider mapping to normalize avatar URLs before storing/returning them.
3. Update chat avatar rendering surfaces to preserve fallback behavior when avatar values are absent or unusable.
4. Verify with manual testing using users with absolute avatar URLs, relative avatar paths, and no avatar.

Rollback:
- Revert the shared resolver and mapping changes; chat will return to current behavior without data migration.

## Open Questions

- Should the shared resolver live in a generic shared utility so auth/profile/chat all use one implementation, or remain chat-local for a smaller initial fix?
- Are there any additional chat/avatar payload shapes beyond `avatar_url` that need normalization in current API responses?
