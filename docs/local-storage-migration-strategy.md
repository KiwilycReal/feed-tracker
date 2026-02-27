# Local Storage Migration Strategy

## Goal
Provide deterministic local schema migration for feed persistence across app upgrades.

## Versioning Model
- Storage uses monotonically increasing integer versions (`StorageVersion`).
- Current version is loaded via `StorageVersionReading.currentVersion()`.
- Successful step completion persists version via `StorageVersionWriting.setCurrentVersion(_:)`.

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
1. App boots and detects current storage version.
2. `StorageMigrator` executes required steps up to app target version.
3. On migration error, app switches to safe mode and emits diagnostics.

## Diagnostics
- Emit migration start/end with target versions.
- Emit step-level errors with target version and operation context.
- Avoid logging user content payloads.
