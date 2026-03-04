# feed-tracker

Autopilot bootstrap for MVP delivery.

## Current Scaffold
- `FeedTrackerCore` Swift package module for shared iOS/watchOS logic
- `feed-tracker-cli` executable target for bootstrap smoke validation
- `FeedTracker.xcodeproj` minimal iOS app target for TestFlight pipeline wiring
- Core baseline contracts for:
  - runtime config loading
  - auth session/token boundaries
  - feed repository and local storage migration

## Quick Start
```bash
swift build
swift test
swift run feed-tracker-cli

# list iOS project targets/schemes
xcodebuild -list -project FeedTracker.xcodeproj

# local simulator build smoke test
xcodebuild -project FeedTracker.xcodeproj \
  -scheme FeedTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

## Architecture
View -> ViewModel -> UseCase -> Repository/Service

## Release Workflow (TestFlight)
- Single CI release path: `.github/workflows/release.yml`
- Default deploy command: `bundle exec fastlane ios testflight_release`
- Signing source-of-truth config: `ci/signing-targets.json`
- Drift/fail-fast checks:
  - `scripts/ci/validate_release_contract.sh`
  - `scripts/ci/check_signing_readiness.py`
- Export compliance default is declared in generated Info.plist via project build setting: `ITSAppUsesNonExemptEncryption=NO`.
- Full architecture doc: `docs/ci/testflight-zero-touch.md`

## Latest MVP Slice
- AC-MVP-10: Live Activity state model + quick-action router/handler (`start_left`, `start_right`, `end_session`)
- AC-MVP-11: Main tab navigation shell (Active Session + History) with updated visual clarity baseline
- AC-P1-13: Siri shortcuts flow (open app / start tracking with side/default strategy / read current status phrase), with startup wiring for `FeedTrackerSiriIntentDependency.handler`
