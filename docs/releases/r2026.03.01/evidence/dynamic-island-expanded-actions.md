# Manual Evidence — AC-R2026.03.01-03 (Dynamic Island expanded actions)

## Goal
验证 Dynamic Island expanded 提供并可执行 3 个动作：
- switch side
- pause
- terminate

## Preconditions
- iOS 17+
- active feeding session 已开始并显示 Live Activity
- 使用 `feature/r2026.03.01-MVP-02-action-parity` 构建

## Steps
1. 在前台开始会话（Left）。
2. 展开 Dynamic Island。
3. 依次触发：
   - switch side（应从 Left -> Right）
   - pause（应进入 paused，不再计时）
   - terminate（应结束会话，Live Activity 关闭）
4. 每步后回到 app 前台检查状态与计时。

## Expected
- switch side 后 activeSide 切换，累计时长连续。
- pause 后 timerStatus=paused，等待 15s 后 elapsed 不增长。
- terminate 后 timerStatus=ended，历史新增记录且不可继续旧会话。

## Suggested artifacts
- expanded actions screen recording
- step screenshots:
  - `ac-r2026.03.01-03-expanded-switch.png`
  - `ac-r2026.03.01-03-expanded-pause.png`
  - `ac-r2026.03.01-03-expanded-terminate.png`

## Automation helper
- `scripts/release/r2026.03.01/record_action_parity_scenes.sh`
