# 雙邊進度看板

> 手動維護的高層進度總覽。即時的 git 狀態請跑 `./scripts/status.sh`。

最後更新:2026-06-29

## 進行中

| 功能 / 整合項 | iOS (sevena) | Backend | 狀態 | 備註 |
|---|---|---|---|---|
| _(範例)_ Profile 畫面重構 | `refactor/profile_screen` | — | 🟡 進行中 | |
|  |  |  |  |  |

## 待整合 / 待對齊

| 項目 | 卡點 | 負責方 |
|---|---|---|
| 取消課程 → 釋放預扣費用 | 後端有 `/cancel` 但學生/老師端皆未接線,預扣寶石恐永久凍結 | iOS + 老師端 + 後端 |
| 上課時間追蹤與計費 | 計費起點為「老師接受」非「真正接通」,無心跳/對帳,爭議大 | 後端主導 + 雙 App 回報 |

> 詳見 [features/1v1-streaming/cancellation-and-fees.md](./features/1v1-streaming/cancellation-and-fees.md)、[time-tracking.md](./features/1v1-streaming/time-tracking.md)。

## 已完成

| 項目 | 完成日 | 備註 |
|---|---|---|
|  |  |  |

圖示:🟢 完成 · 🟡 進行中 · 🔴 卡住 · ⚪️ 未開始
