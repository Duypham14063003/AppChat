## Why

Users currently can only make standard phone calls via their cellular provider, which incurs costs and lacks context (e.g., they cannot easily call within the app's ecosystem). Adding a VoIP (Voice over IP) calling feature allows for free, integrated, and high-quality audio/video communication directly within the app, similar to modern messaging platforms like Messenger or WhatsApp.

## What Changes

- Add a dedicated calling system using WebRTC for real-time communication.
- Replace the existing `tel:` link in `ChatScreen` with an internal VoIP calling trigger.
- Implement an incoming call interface that works even when the app is in the background.
- Implement an active call interface for both audio and video calls.
- Add call status messages to the chat history (e.g., "Missed call", "Call ended").
- Integrate with system-level calling features (CallKit for iOS, ConnectionService for Android) for a native experience.

## Capabilities

### New Capabilities
- `voip-calling`: Core logic for initiating, receiving, and managing real-time audio/video calls.
- `call-signaling`: WebSocket-based signaling protocol to manage call lifecycle (invite, accept, reject, hangup, WebRTC negotiation).
- `call-ui`: User interface components for incoming, outgoing, and active calls.

### Modified Capabilities
- None

## Impact

- **Dependencies**: Add `flutter_webrtc`, `flutter_callkit_incoming`, `permission_handler`.
- **Network**: Increased bandwidth usage during calls; update WebSocket protocol to handle signaling.
- **UI/UX**: New screens and overlays for calls; update `ChatScreen` and `ChatListScreen` components.
- **Permissions**: Requires Camera and Microphone permissions.
