# 功能:1v1 教學視訊串流

回推自雙端 codebase 的整合記錄。**分端記錄:**

- [ios.md](./ios.md) —— iOS 學生端(`sevena/`):Agora 加入頻道 + 輪詢配對。
- [backend.md](./backend.md) —— 後端(`sevena-backend/`):配對引擎 + signaling 狀態機 + 角色資料模型。

**跨端議題(三端對齊方案):**

- [cancellation-and-fees.md](./cancellation-and-fees.md) —— 任一方取消課程(開始前/剛開始)的通知與費用處理。⚠️ 後端有 `/cancel` 退款端點,但兩端都沒接線 → 預扣寶石可能永久凍結。
- [time-tracking.md](./time-tracking.md) —— 上課時間追蹤與計費(話家常/斷線/超時等爭議),含程式碼處理與業界做法建議。⚠️ 計費起點設在「老師接受」而非「真正接通」→ 超收。

> 老師端 codebase 已取得(`sevena-teacher/`):交易生命週期(accept/decline/cancel/end)幾乎全缺,詳見上述兩篇跨端議題。

## 速覽

| 面向 | 結論 |
|---|---|
| 連線技術 | Agora RTC SDK(頻道會合,非裸 WebRTC、非真 P2P) |
| 會合鍵 | `channel_name = session_<sessionId>`,雙方加入同一頻道 |
| 認知對方 | **後端配對系統**(按臉部/產品/風格相似度自動選老師),FCM 邀約 + 學生輪詢。非配對碼、非分享連結 |
| 鑑權 | ⚠️ 目前 `token: null`(App ID-only),Token Server 待補 |
