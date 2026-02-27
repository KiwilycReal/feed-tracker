# Local Storage Migration Strategy

## Goal
Provide deterministic local schema migration for feed persistence across app upgrades.

## Versioning Model
- Storage uses monotonically increasing integer versions (`StorageVersion`).
- Feeding-session persistence file (`feeding-sessions.json`) uses a versioned envelope:
  - `schemaVersion`: integer
  - `sessions`: array of `FeedingSession`
- Current persisted schema version is **v2** (`FileFeedingSessionRepository.currentSchemaVersion`).
- Legacy payloads are auto-migrated on repository bootstrap:
  - legacy raw array payload (`[FeedingSession]`) -> v2 envelope
  - v1 envelope payload (`schemaVersion = 1`) -> v2 envelope

## Migration Execution Rules
- Migrations are forward-only.
- Downgrade requests are rejected (`downgradeNotSupported`).
- Migration fails fast when path is incomplete (`missingPath`).
- Each step targets exactly one version and must be idempotent.

## Step Contract
Each `StorageMigrationStep` must:
- declare `targetVersion`
- execute data/schema transformation in `run()`
- be safe to retry after interruption

## Rollout Pattern
1. App boots and initializes `FileFeedingSessionRepository` with `feeding-sessions.json`.
2. Repository decodes current payload and evaluates `schemaVersion`.
3. If payload is legacy (`[FeedingSession]`) or v1 envelope, repository migrates to v2 and rewrites atomically.
4. On migration error, app switches to safe mode and emits diagnostics.

## Diagnostics
- Emit migration start/end with target versions.
- Emit step-level errors with target version and operation context.
- Avoid logging user content payloads.
