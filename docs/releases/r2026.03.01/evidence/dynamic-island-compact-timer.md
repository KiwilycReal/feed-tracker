# Manual Evidence — AC-R2026.03.01-02 (Dynamic Island compact/minimal timer continuity)

## Goal
证明 Dynamic Island compact/minimal 计时在运行会话中连续增长（不冻结/不回跳）。

## Environment
- iPhone with Dynamic Island (preferred real device)
- iOS 17+
- Build from branch `feature/r2026.03.01-MVP-01-live-activity-lifecycle`

## Timed checkpoint script
1. 开始一个 active session（Left/Right 任意）。
2. 切到主屏，观察 compact/minimal。
3. 在 T+0s、T+30s、T+60s、T+90s 分别记录 compact/minimal 显示时间。
4. 在 T+90s 后回到 App，验证主界面 totalElapsed 与岛上显示一致（允许 ≤1s 误差）。

## Pass criteria
- P1: T+30/T+60/T+90 读数单调递增。
- P2: 任意 checkpoint 之间无重置或倒退。
- P3: 回到前台后主界面 elapsed 与岛上 elapsed 对齐（误差 ≤1s）。

## Suggested artifact table
| Checkpoint | Island timer | In-app timer | Delta |
|---|---:|---:|---:|
| T+0 | 00:00 | 00:00 | 0s |
| T+30 | 00:30 | 00:30 | 0s |
| T+60 | 01:00 | 01:00 | 0s |
| T+90 | 01:30 | 01:30 | 0s |

## Notes
- 本次实现通过 `capturedAt + baselineElapsed` 投影方式保证 compact/minimal 连续计时，无需每秒后台写入。
- Use script: `scripts/release/r2026.03.01/record_live_activity_scenes.sh`
