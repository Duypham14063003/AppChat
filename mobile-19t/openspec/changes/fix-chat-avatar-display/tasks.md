## 1. Avatar Resolution

- [x] 1.1 Add a shared Flutter-side chat avatar URL resolver for absolute, relative, and empty avatar values
- [x] 1.2 Update chat data mapping/providers to normalize conversation, group, and member avatar values before storage/use

## 2. UI Fallbacks

- [x] 2.1 Update conversation list avatar rendering to use normalized values and initials/icon fallback behavior
- [x] 2.2 Update other chat surfaces that render avatar data (picker/detail/member views) to use the same behavior

## 3. Verification

- [x] 3.1 Add or update tests for avatar normalization and fallback behavior
- [ ] 3.2 Manually verify direct chat avatars, group avatars, and no-avatar fallback states in the Flutter messaging UI
