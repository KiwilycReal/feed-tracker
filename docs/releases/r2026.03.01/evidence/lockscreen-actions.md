# Manual Evidence — AC-R2026.03.01-04 (Lock screen action parity)

## Goal
验证锁屏 Live Activity 与 expanded island 具备相同行为能力：
- switch side
- pause
- terminate

## Preconditions
- iOS 17+
- active feeding session running
- 锁屏可见 Live Activity

## Steps
1. 锁屏状态下触发 switch side。
2. 解锁进 app 验证 side 已切换且计时连续。
3. 再次锁屏触发 pause。
4. 等待 20s 后解锁验证 elapsed 无漂移（保持 pause 前值）。
5. 再锁屏触发 terminate。
6. 解锁验证会话结束，Live Activity 消失，历史已写入。

## Expected parity assertions
- capability parity: expanded/lock screen 均有 switch+pause+terminate
- behavior parity: 同一动作结果一致（状态机转换一致）
- stale action safety: ended 后重复动作不应造成状态回退或重复写入

## Suggested artifacts
- lock screen interaction recording
- screenshots:
  - `ac-r2026.03.01-04-lock-switch.png`
  - `ac-r2026.03.01-04-lock-pause.png`
  - `ac-r2026.03.01-04-lock-terminate.png`
