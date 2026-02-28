# Manual Diagnostics Export (Post-release)

## Purpose
Generate a redacted diagnostics JSON bundle from inside the app for incident triage and QA verification.

## Where in app
- Open **History** tab
- Tap top-right overflow (`…`)
- Tap **Export Diagnostics**
- iOS share sheet opens with generated JSON file

## Export payload schema
The exported JSON includes:
- `appVersion`
- `buildNumber`
- `deviceModel`
- `sourceTag`
- `exportedAt` (ISO8601)
- `events` (last N redacted structured events, minimum export window target is 100)
- `lastErrorSummary`

## Event coverage
Structured events are emitted for:
- Session transitions (start/switch/pause/resume/stop/end)
- Persistence actions (history reload/edit/delete + completed session persist)
- Live Activity key actions (start-left/start-right/end-session)
- Error summaries for above flows and diagnostics export errors

## Redaction policy
- Sensitive metadata keys are masked (`<redacted>`), e.g. note/message/token/password/api_key/email.
- Sensitive error messages are redacted to `<redacted>` when they contain auth/secret markers.
- Non-sensitive values are truncated to avoid oversized payloads.

## Validation checklist
1. Trigger at least one session action and one history action.
2. Export diagnostics from History menu.
3. Confirm JSON is generated and shareable.
4. Verify redaction fields are masked (`<redacted>`).
5. Verify payload includes app version/build/device/source/timestamp and event list.
