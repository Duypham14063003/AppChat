## ADDED Requirements

### Requirement: Master-detail chat layout on wide screens
On screens ≥768px, the `MainShell` SHALL display `ChatListScreen` as a persistent 320px-wide left sidebar alongside the current route's content in the remaining space. When the current route is `/chat` (no conversation selected), the right panel SHALL show an empty state with centered text "Chọn cuộc trò chuyện". When the current route is `/chat/:id`, the right panel SHALL show the `ChatScreen`. On screens <768px, the existing full-screen push navigation SHALL be preserved unchanged.

#### Scenario: Wide screen shows chat list sidebar
- **GIVEN** the app is on a screen ≥768px wide and the user is on the `/chat` route
- **WHEN** the MainShell renders
- **THEN** a 320px chat list sidebar appears on the left with an empty state panel on the right

#### Scenario: Selecting a conversation on wide screen
- **GIVEN** the app is on a wide screen showing the master-detail layout
- **WHEN** the user taps a conversation in the sidebar
- **THEN** the right panel shows the ChatScreen for that conversation without a full-screen transition

#### Scenario: Selected conversation is highlighted
- **GIVEN** the app is on a wide screen with a conversation open in the right panel
- **WHEN** the chat list sidebar renders
- **THEN** the currently active conversation tile has a `AppColors.surfaceVariant` background highlight

### Requirement: Navigation method adapts to screen width
On wide screens, `ChatListScreen` SHALL use `context.go('/chat/$id')` to navigate to conversations (replacing the route). On narrow screens, it SHALL continue using `context.push('/chat/$id')` (pushing onto the stack).

#### Scenario: Wide screen uses go() navigation
- **GIVEN** the app is on a wide screen
- **WHEN** the user taps a conversation tile
- **THEN** the route changes via `go()` and the right panel updates without stacking

#### Scenario: Narrow screen uses push() navigation
- **GIVEN** the app is on a narrow screen
- **WHEN** the user taps a conversation tile
- **THEN** the route changes via `push()` and a full-screen ChatScreen is pushed
