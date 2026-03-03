# Manual Evidence — AC-R2026.03.01-01 (Live Activity lifecycle continuity)

## Goal
证明活跃喂奶会话在前台/后台/退出后重启期间，Live Activity 不丢失并保持可继续更新。

## Environment
- Build: Debug iOS simulator/device with branch `feature/r2026.03.01-MVP-01-live-activity-lifecycle`
- iOS: 17+
- App build installed fresh

## Steps
1. 启动 App，进入 Active Session，点击 Left 开始。
2. 观察 Live Activity 出现（锁屏或 Dynamic Island）。
3. 回到桌面（background）等待 20 秒。
4. 重新进入 App，确认会话仍在运行。
5. 再次退到后台并从任务管理器强制结束 App。
6. 重新打开 App，确认会话状态被恢复，Live Activity 仍可更新。
7. 最后点击 End，确认 Live Activity 结束并消失。

## Checkpoints
- C1: 背景后 Live Activity 仍可见（PASS/FAIL）
- C2: 强杀后重启，活跃会话恢复（PASS/FAIL）
- C3: 强杀后重启，Live Activity 持续更新（PASS/FAIL）
- C4: 结束会话后 Live Activity 结束，不再残留（PASS/FAIL）

## Suggested artifacts
- Screenshot/video at:
  - foreground running
  - background/lock-screen running
  - post-relaunch running
  - post-end terminated
- 附件命名建议：
  - `ac-r2026.03.01-01-foreground.png`
  - `ac-r2026.03.01-01-background.png`
  - `ac-r2026.03.01-01-relaunch.png`
  - `ac-r2026.03.01-01-ended.png`

## Automation helper
- Use script: `scripts/release/r2026.03.01/record_live_activity_scenes.sh`
