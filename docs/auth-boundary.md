# Auth Boundary (iOS/watchOS Clients)

## Scope
This document defines auth responsibilities for client-side layers and shared core services.

## Boundary Rules
- UI/ViewModel layers **must not** persist tokens directly.
- UseCase layer requests authentication state via `AccessTokenProviding`.
- Token/session persistence belongs to `AuthSessionStoring` implementations in service/repository layer.
- Any network adapter receives bearer token from `AccessTokenProviding` only.

## Session Model
- `AuthSession` stores:
  - `accessToken`
  - optional `refreshToken`
  - `expiresAt`
- Session validity is evaluated before each protected API call.

## Token Lifecycle Strategy
1. Login flow writes `AuthSession` using `AuthSessionStoring.save(_:)`.
2. Request pipeline asks `AccessTokenProviding` for token.
3. If token is expired, provider returns `nil` and caller triggers re-auth/refresh use case.
4. Logout clears session with `AuthSessionStoring.clear()`.

## Security Baseline
- Store production sessions in Keychain-backed implementation (to be added in AC-MVP-06).
- Never log raw access/refresh tokens.
- Keep refresh logic centralized in UseCase/Service layer.
- Ensure watchOS extension reuses same abstraction and policy.
