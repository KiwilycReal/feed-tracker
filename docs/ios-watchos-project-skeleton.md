# iOS/watchOS Project Skeleton (Bootstrap)

## Objective
Define an initial implementation skeleton for iOS + watchOS delivery, with shared core domain logic and executable bootstrap validation.

## Proposed Structure
- `Sources/FeedTrackerCore/` shared domain/use-case logic (iOS + watchOS)
- `Sources/FeedTrackerCLI/` executable smoke scaffold for CI bootstrap
- `Tests/FeedTrackerCoreTests/` shared core tests
- Future Xcode targets (next phase):
  - `apps/iOS/FeedTrackerApp`
  - `apps/watchOS/FeedTrackerWatchApp`

## Architecture Baseline
View -> ViewModel -> UseCase -> Repository/Service

Rules:
- No business logic in View layer
- Side-effects restricted to Service/Repository
- Errors must be observable
