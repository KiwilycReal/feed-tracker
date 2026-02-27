# AC Traceability

## AC Catalog and Current Status

| AC ID | Scope | Status | Evidence Source |
|---|---|---|---|
| AC-MVP-01 | Repo/project bootstrap | PASS | `Package.swift`, `Sources/FeedTrackerCLI/main.swift`, `docs/ios-watchos-project-skeleton.md` |
| AC-MVP-02 | Env/config baseline | PASS | `.env.example`, `docs/secrets-manifest.md`, `Sources/FeedTrackerCore/Configuration/RuntimeConfig.swift`, `Tests/FeedTrackerCoreTests/RuntimeConfigLoaderTests.swift` |
| AC-MVP-03 | Auth/security baseline | PASS | `docs/auth-boundary.md`, `Sources/FeedTrackerCore/Security/AuthSession.swift`, `Tests/FeedTrackerCoreTests/AuthSessionStoreTests.swift` |
| AC-MVP-04 | Domain/data model baseline | PASS | `Sources/FeedTrackerCore/FeedItem.swift`, `Sources/FeedTrackerCore/Persistence/FeedItemRepository.swift`, `Sources/FeedTrackerCore/Persistence/StorageMigration.swift`, `docs/local-storage-migration-strategy.md`, `Tests/FeedTrackerCoreTests/FeedItemTests.swift`, `Tests/FeedTrackerCoreTests/InMemoryFeedItemRepositoryTests.swift` |
| AC-MVP-05 | Timer engine state machine | PASS | `Sources/FeedTrackerCore/Session/SessionTimerEngine.swift`, `Tests/FeedTrackerCoreTests/SessionTimerEngineTests.swift` |
| AC-MVP-06 | Active session UI live timing | PASS | `Sources/FeedTrackerCore/Features/ActiveSessionViewModel.swift`, `Sources/FeedTrackerCore/UI/ActiveSessionView.swift`, `Tests/FeedTrackerCoreTests/ActiveSessionViewModelTests.swift` |
| AC-MVP-07 | History list | PASS | `Sources/FeedTrackerCore/Persistence/FeedingSessionRepository.swift`, `Sources/FeedTrackerCore/Features/HistoryListViewModel.swift`, `Sources/FeedTrackerCore/UI/HistoryListView.swift`, `Tests/FeedTrackerCoreTests/HistoryAndEditIntegrationTests.swift` |
| AC-MVP-08 | Edit historical session | PASS | `Sources/FeedTrackerCore/Session/FeedingSession.swift`, `Sources/FeedTrackerCore/Features/EditSessionViewModel.swift`, `Tests/FeedTrackerCoreTests/HistoryAndEditIntegrationTests.swift` |
| AC-MVP-09 | Delete historical session | PASS | `Sources/FeedTrackerCore/Features/HistoryListViewModel.swift`, `Sources/FeedTrackerCore/UI/HistoryListView.swift`, `Tests/FeedTrackerCoreTests/HistoryAndEditIntegrationTests.swift` |
| AC-MVP-10 | Live Activity / Dynamic Island actions | TODO | pending ActivityKit implementation |
| AC-MVP-11 | Main navigation + visual quality baseline | TODO | pending UI structure and review checklist |
| AC-MVP-12 | Local persistence durability + migration | PASS | `Sources/FeedTrackerCore/Persistence/FileFeedingSessionRepository.swift`, `docs/local-storage-migration-strategy.md`, `Tests/FeedTrackerCoreTests/FileFeedingSessionRepositoryTests.swift` |
| AC-P1-13 | Siri shortcuts (open/start/read) | TODO | pending AppIntents implementation |

## Primary Requirement Source
- `docs/pm-prd-v1.md`

## Current Implementation Focus
- Batch B4 targets AC-MVP-09..12.
