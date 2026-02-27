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
