# HF13 — Live Activity layout-fit cleanup

## Scope
Covers hotfix `hf13` for release `r2026.03.01`.

## Goal
Tighten the Live Activity presentation so the remaining layout-fit issues are reduced without touching the HF12 timer/lifecycle architecture:
- expanded Dynamic Island top line should sit more safely inside the capsule
- expanded middle timer row should consume less height
- lock-screen Live Activity should be less likely to clip while preserving action clarity

## Changes
All changes are layout-only and are isolated to `LiveActivityWidgetExtension/FeedTrackerLiveActivityWidget.swift`.

### Expanded Dynamic Island
- moved the top metadata/clock row slightly further inward with larger top/side padding
- reduced the top-row visual footprint by slightly shrinking badge and clock typography
- reduced the middle row footprint by lowering timer fonts, action button size, panel height, and inter-panel spacing
- tightened the bottom action row height and spacing for more breathing room in the full expanded presentation

### Lock-screen Live Activity
- tightened header spacing and clock typography
- reduced timer row height, font sizes, and center pause button size
- reduced bottom pill action height and spacing

## Non-goals
- no changes to timer state, projection, lifecycle ownership, or quick-action behavior
- no changes to core ActivityKit reconciliation logic

## Validation
### Automated
- `swift test`
- `xcodebuild -project FeedTracker.xcodeproj -scheme FeedTracker -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## Expected outcome
HF13 keeps the HF12 timer architecture intact while giving the expanded island and lock-screen surfaces a smaller, safer layout envelope with less risk of top-line or overall content clipping.
