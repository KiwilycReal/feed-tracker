# Known Issues — r2026.03.01

## Confirmed known issues
- None classified as release blocker at prep time.

## Non-blocking observations
1. SwiftLint warnings (non-serious, existing style debt):
   - `StorageMigration.swift` identifier length warning (`to`)
   - function/type length warnings in feature files
2. Manual lock screen evidence capture still requires physical-device validation for full UX confidence.

## Monitoring focus post-release
- Live Activity stale action behavior after prolonged background periods
- Dynamic Island timer projection drift tolerance under low-power/background constraints
- Duplicate terminate action frequency in diagnostics events
