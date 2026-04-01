# HF14 — Live Activity UI relayout

## Scope
Covers hotfix `hf14` for release `r2026.03.01`.

## Goal
Reconstruct the Live Activity layout so all existing UI content still appears, but the presentation no longer rides the host surface edges:
- keep the current timer/state/action behavior unchanged
- preserve the existing content set across lock screen and Dynamic Island surfaces
- replace fixed-height fit tuning with a safer shared layout structure
- reduce the chance of clipping against the capsule/card borders across relevant Live Activity surfaces

## Changes
All code changes remain isolated to `LiveActivityWidgetExtension/FeedTrackerLiveActivityWidget.swift`.

### Shared layout architecture
- introduced a shared `LiveActivitySurfaceSpec` so lock-screen and expanded-island surfaces use one layout vocabulary instead of one-off magic numbers
- rebuilt header, metric strip, and action strip as reusable surface sections
- switched timer cards from fixed heights to flexible minimum heights with internal padding so content can breathe instead of being forced into a rigid box

### Primary timer surfaces
- replaced the previous single hard-coded timer row with an adaptive `primaryMetricsStrip`
- the timer strip now uses `ViewThatFits` to fall back to a denser horizontal arrangement before the host starts clipping content
- active/total timer cards still render the same timer/state data and the same central pause/resume control

### Action surfaces
- rebuilt the switch/stop row into a shared `actionStrip`
- the action strip now also uses `ViewThatFits`, allowing a vertical fallback if a host surface becomes too narrow instead of truncating or pressing controls into borders

### Surface-specific tuning
- lock screen and expanded Dynamic Island now each provide only a spec (fonts, spacing, control sizes, padding) while sharing the same structure
- compact leading/trailing views keep the same content but allow slightly more scale compression for safer fit

## Non-goals
- no timer-state, projection, lifecycle, or intent-routing changes
- no content removal from any existing Live Activity surface
- no changes outside the Live Activity widget file

## Validation
### Automated
- `swift test`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Expected outcome
HF14 keeps the HF12/HF13 behavior intact while moving the Live Activity UI onto a more resilient shared layout system, so the lock-screen and expanded-island surfaces keep their full content without hugging or clipping against the host borders.
