## ADDED Requirements

### Requirement: Forwarded message header in MessageBubble
The MessageBubble SHALL display a "Chuyển tiếp từ [Name]" header above the message content when the message has `forwardedFromId` set. The header SHALL use `AppColors.gold` color, italic style, 12px font size, with a "↪" prefix icon.

#### Scenario: Display forwarded message with attribution
- **WHEN** a message has `forwardedFromSender` = "Nguyễn Văn A"
- **THEN** MessageBubble shows "↪ Chuyển tiếp từ Nguyễn Văn A" header above the content

#### Scenario: Display anonymous forwarded message
- **WHEN** a message has `forwardedFromId` set but `forwardedFromSender` is null
- **THEN** MessageBubble shows "↪ Tin nhắn chuyển tiếp" header above the content

#### Scenario: Non-forwarded message unchanged
- **WHEN** a message has no `forwardedFromId`
- **THEN** MessageBubble renders normally without any forward header

### Requirement: Forward header for all message types
The forward header SHALL appear for all forwarded message types: text, image, album, video, and voice. The header SHALL be positioned above the message content (text, media, or voice bubble).

#### Scenario: Forwarded image message
- **WHEN** a forwarded message has type "image"
- **THEN** the forward header appears above the image, within the bubble

#### Scenario: Forwarded voice message
- **WHEN** a forwarded message has type "voice"
- **THEN** the forward header appears above the voice bubble waveform

