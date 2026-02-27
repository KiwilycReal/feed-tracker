# Implementation Checklist (AC-MVP-01..04)

## AC-MVP-01 Repo/Project Bootstrap
- [x] Repository initialized and pushed
- [x] Baseline scaffold directories created
- [x] Shared Swift package scaffold added
- [x] Minimal executable target added

## AC-MVP-02 Env/Config Baseline
- [x] `.env.example` added
- [x] Secrets placeholder manifest added
- [ ] Runtime config loader (Swift) to be implemented

## AC-MVP-03 Auth/Security Baseline
- [ ] Auth boundary doc for iOS/watchOS clients
- [ ] Token/session handling strategy
- [ ] Security middleware/service abstraction in core layer

## AC-MVP-04 Domain/Data Model
- [x] Initial `FeedItem` domain model scaffolded
- [ ] Persistence contract (repository protocol)
- [ ] Migration/versioning strategy for local storage
