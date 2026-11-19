# Account avatar contract

Implemented in source; not deployed or real-account tested.

## Upload

`POST /api/account/avatar` with JSON `{ "image": "data:image/png;base64,..." }`.

- Existing unexpired, authenticated Google session cookie and exact configured
  `Origin` required. Anonymous, GitHub, and bearer-only access cannot upload.
- No caller-supplied account identifier: ownership is the verified Google subject.
- Only PNG/JPEG data URIs accepted. Remote URLs and WebP are rejected (422).
  Clients accepting WebP in their picker must convert locally to PNG/JPEG first.
- Uses existing bounded request/image decoding, EXIF orientation normalization,
  maximum 1,048,576 upload pixels, RGB PNG output, and private SQLite storage.
- Atomic replacement counts against the shared storage quota. A failed upload
  preserves the previous avatar. Logout/expiry during decoding prevents a write.
- Success: `{ "user": { "provider": "google", "id": "...", "avatar":
  "data:image/png;base64,...", ... }, "balance": 0 }`.
  Balance is authoritative server state, not modified by photo upload.
- Authentication errors use 401/403; invalid image/body 422; oversized request
  413; exhausted storage 507. Responses use the existing no-store middleware.
- No inference, provider calls, token loading, or paid operation is performed.

## Restore

`POST /api/account` returns the stored photo in `user.avatar` for the current
Google subject. Successful web/Android Google login also includes `user.avatar`.
This is separate from Google's allowlisted remote `user.picture`; uploaded
avatars override nothing in identity claims and must be preferred by the client.

The client must verify `user.provider == 'google'` and `user.id` matches its
active account before accepting a restored avatar. Missing `avatar` means no
uploaded photo for that account, not permission to reuse a different account's
local photo. Logout invalidates the session, not the durable uploaded photo.
A new authenticated session for the same Google subject restores the photo after
server restart; stale cookies do not survive restart authentication.

This endpoint does not upload or restore closet/backup/mannequin state. Those
remain the existing client-local account-scoped functionality. There is no new
`/api/account/restore` route and no anonymous account recovery capability.

## Offline evidence

`test_account_avatar.py` exercises upload, account readback, reauthentication and
server restart, ownership isolation, invalid payload preservation, exact-origin
and authentication gates, no spending, logout during normalization, quota
replacement/rollback, and JPEG-to-PNG metadata removal. Tests use synthetic
identity claims with real local SQLite and in-process ASGI transport.
