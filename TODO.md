# TODO - ShadowChat X WhatsApp-style behavior

## Backend
- [ ] Extend `GET /conversations/{username}` response to include `unread_count` for that user per other participant.

## Frontend - Models/Services
- [ ] Update `Conversation` model to include `unreadCount`.
- [ ] Update `ConversationService` parsing.
- [ ] Implement search UI: TextField triggers `GET /users/search?username=query` via `ApiService.searchUsers`.

## Frontend - Home UI
- [ ] Home list shows only real conversations from `/conversations/{username}`.
- [ ] Add unread message badge (based on `unreadCount`).
- [ ] Real-time conversation updates: update last message/time and unread badge on WS events.

## Frontend - Chat UI
- [ ] Fix sender/receiver visibility so only sender/receiver see content (remove “From/To” metadata).
- [ ] Mark received messages as seen on open (server supports mark-seen by `_id`).

## Local Notifications
- [ ] Add `flutter_local_notifications` dependency.
- [ ] Create `ChatVisibility` service to let home know which chat is currently open.
- [ ] When WS receives a new message for a chat that isn't open, show local notification to receiver.

## Quality
- [ ] Remove/ignore any dummy/mock behavior.
- [ ] Ensure no hardcoded usernames anywhere.

