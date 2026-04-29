# Offline-first Sync Queue (Flutter + Firestore)

This project implements an offline-first notes feature with durable local
storage, persisted sync queue, retry logic, idempotent writes, and basic sync
observability.

## Run Instructions

1. Install dependencies:
   - `flutter pub get`
2. Ensure Firebase is configured (already wired via `firebase_options.dart`).
3. Set Firestore rules for assignment/demo use:
   - `allow read, write: if true;`
4. Start app:
   - `flutter run`

## Approach

- **Local-first UX**
  - Notes are read from SQLite immediately on `LoadNotes`.
  - App then performs a background Firestore refresh and upserts newer data.
- **Offline writes**
  - `add note` and `toggle favorite` are applied locally first.
  - Each mutation is added to durable `sync_queue` in SQLite.
- **Durability**
  - Queue is persisted in local database and survives app restarts.
- **Retry + backoff**
  - Sync retries once with a 2s backoff and then marks action failed.
- **Idempotency**
  - Firestore write target is deterministic (`notes/{noteId}`) with merge set.
  - Queue action ID uses deterministic idempotency key format:
    `type:noteId:timestampMs`.
- **Conflict strategy**
  - Last-write-wins (`updated_at`) during remote refresh merge.
- **Observability**
  - UI shows pending queue count, sync success count, sync failure count.
  - Logs include queue size, retry scheduled, sync success, sync failed.
  - Connectivity restore triggers automatic sync + refresh.

## Tradeoffs

- LWW can overwrite concurrent edits instead of merging field-level intent.
- One retry is simple and predictable but not sufficient for flaky long outages.
- Open Firestore rules are acceptable for assignment only, not production.

## Limitations

- No authenticated user ownership or per-user access control.
- No dead-letter handling beyond status=`failed`.
- No background service for periodic sync when app is terminated.
- No TTL for cached remote reads yet.

## Next Steps

- Add exponential retry policy with max attempts + jitter.
- Add queue dead-letter view and retry-failed action.
- Add cache TTL and stale indicator.
- Add richer tests around queue ordering and failure transitions.

## AI Prompt Log

### Prompt 1
- **Accepted**
  - Yes for assignment scope; use open rules in Firestore console.
- **Rejected**
  - Production-grade security posture because not required for assignment demo.

### Prompt 2
- **Prompt**
  - "Check assignment criteria against current project and fill gaps."
- **Accepted**
  - Gap analysis against each requirement.
  - Add connectivity-based automatic sync on network restore.
  - Add idempotency helper and unit test.
  - Replace README with explicit approach/tradeoffs/verification sections.
- **Rejected**
  - Overengineering retry policy beyond assignment minimum.

## Verification Evidence

Capture screenshots/log snippets for the following and attach in submission.

### Scenario A: Offline Add Note
- Turn off internet.
- Add a note.
- Verify note appears instantly from local DB.
- Verify pending queue increments.
- Turn internet on.
- Verify sync success log and pending queue decrements.

### Scenario B: Offline Toggle Favorite
- Turn off internet.
- Toggle favorite on an existing note.
- Verify local UI updates immediately.
- Verify queue pending count increments.
- Turn internet on and verify sync + remote refresh updates.

### Scenario C: Retry + Idempotency
- Add or modify note.
- Keep internet unstable (toggle airplane mode quickly during sync), then tap `Sync Now`.
- Verify one retry is scheduled in logs, then success/failure status changes.
- Verify Firestore contains one final document per note ID (no duplicates).

### Logs/Counters to collect
- `QUEUE SIZE: ...`
- `SYNC RETRY SCHEDULED: ...`
- `SYNC SUCCESS: ...`
- `SYNC FAILED: ...`
- UI counters: pending, success, failed

## Test Command

- Run tests:
  - `flutter test`
