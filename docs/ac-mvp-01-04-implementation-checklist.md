# Implementation Checklist (AC-MVP-01..04)

## AC-MVP-01 Repo/Project Bootstrap
- [x] Repository initialized and pushed
- [x] Baseline scaffold directories created
- [x] Shared Swift package scaffold added
- [x] Minimal executable target added

## AC-MVP-02 Env/Config Baseline
- [x] `.env.example` added
- [x] Secrets placeholder manifest added
- [x] Runtime config loader (Swift) implemented (`RuntimeConfigLoader`)

## AC-MVP-03 Auth/Security Baseline
- [x] Auth boundary doc for iOS/watchOS clients (`docs/auth-boundary.md`)
- [x] Token/session handling strategy defined and scaffolded (`AuthSession` + provider/store contracts)
- [x] Security middleware/service abstraction in core layer (`AccessTokenProviding`/`AuthSessionStoring`)

## AC-MVP-04 Domain/Data Model
- [x] Initial `FeedItem` domain model scaffolded
- [x] Persistence contract (repository protocol) (`FeedItemRepository`)
- [x] Migration/versioning strategy for local storage (`StorageMigrator` + strategy doc)

## AC Evidence Table (PR-ready)

| AC ID | Status | Evidence |
|---|---|---|
| AC-MVP-01 | PASS | `Package.swift`, `Sources/FeedTrackerCLI/main.swift`, `docs/ios-watchos-project-skeleton.md` |
| AC-MVP-02 | PASS | `.env.example`, `docs/secrets-manifest.md`, `Sources/FeedTrackerCore/Configuration/RuntimeConfig.swift`, `Tests/FeedTrackerCoreTests/RuntimeConfigLoaderTests.swift` |
| AC-MVP-03 | PASS | `docs/auth-boundary.md`, `Sources/FeedTrackerCore/Security/AuthSession.swift`, `Tests/FeedTrackerCoreTests/AuthSessionStoreTests.swift` |
| AC-MVP-04 | PASS | `Sources/FeedTrackerCore/FeedItem.swift`, `Sources/FeedTrackerCore/Persistence/FeedItemRepository.swift`, `Sources/FeedTrackerCore/Persistence/StorageMigration.swift`, `docs/local-storage-migration-strategy.md`, `Tests/FeedTrackerCoreTests/FeedItemTests.swift`, `Tests/FeedTrackerCoreTests/InMemoryFeedItemRepositoryTests.swift` |
