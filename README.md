# feed-tracker

Autopilot bootstrap for MVP delivery.

## Current Scaffold
- `FeedTrackerCore` Swift package module for shared iOS/watchOS logic
- `feed-tracker-cli` executable target for bootstrap smoke validation
- Core baseline contracts for:
  - runtime config loading
  - auth session/token boundaries
  - feed repository and local storage migration

## Quick Start
```bash
swift build
swift test
swift run feed-tracker-cli
```

## Architecture
View -> ViewModel -> UseCase -> Repository/Service

## Release Workflow (Bootstrap)
- GitHub Action: `.github/workflows/release.yml`
- Default deploy command: `bundle exec fastlane ios testflight`
- `fastlane/Fastfile` currently provides a bootstrap lane that validates required release secrets wiring and exits successfully.
- Actual binary signing/upload implementation will be wired when the iOS app target/project is introduced.

## Latest MVP Slice
- AC-MVP-10: Live Activity state model + quick-action router/handler (`start_left`, `start_right`, `end_session`)
- AC-MVP-11: Main tab navigation shell (Active Session + History) with updated visual clarity baseline
- AC-P1-13: Siri shortcuts flow (open app / start tracking with side/default strategy / read current status phrase), with startup wiring for `FeedTrackerSiriIntentDependency.handler`
