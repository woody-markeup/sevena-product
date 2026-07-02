# 1v1 教學串流 — 上課時間追蹤與計費

> 回推自三端 codebase 並提出對齊方案。
> 主題：**上課時間怎麼算、由誰權威計時、課中不可預期狀況（話家常、斷線、超時、一方掛機）如何計費、爭議如何防。**
> 取消/退款見 [cancellation-and-fees.md](./cancellation-and-fees.md)。

## 一句話

目前**沒有任何一端可靠地追蹤真實上課時間**：後端把計費起點設在「老師按接受」而非「真正接通」，學生端只有本地倒數計時器（從不回報、fire-and-forget），老師端計時器純顯示。要降低爭議，必須讓**後端成為唯一計時權威**，以「雙方都在線」為計費區間，並用 RTC 事件 + 心跳交叉驗證、全程留審計軌跡。

---

## 1. 現況（code reality）

| 面向 | 現況 | 問題 | 位置 |
|---|---|---|---|
| 計費起點 | `actual_start_time = NOW()` 在**老師按接受**時設定 | 含「接受→真正接通」空窗（可能數十秒～數分鐘），**超收** | `service/sessionMatcher.js:198` |
| 計費終點 | `/end` 被呼叫的當下時間 | 取決於誰、何時呼叫 | `routes/call.js:562-569` |
| 時長算法 | `(actualEnd - actualStart)/60000` 分鐘 | 來源時間不準，結果就不準 | `routes/call.js:562-564` |
| `in_progress` 狀態 | **從未被設定**（程式只用 `matched`→`completed`） | 後端不知道「真的接通了沒」 | 全 `call.js` 無 set `in_progress` |
| 誰呼叫 `/end` | 學生端僅在 `.completed` 時、`try?` fire-and-forget | 失敗不重試 → 不結算、寶石卡凍結 | `UseCases/CallUseCase.swift:170-171` |
| 老師端 `/end` | **完全不呼叫**，`endCall()` 只 `leaveChannel()` | 老師主動結束不會結算 | `TeacherAgoraManager.swift:391` |
| 學生端計時 | 本地 `tick()` 倒數，進 `.connected` 才起算 | **不回報後端**，純 UI；無心跳 | `UseCases/CallUseCase.swift:181-205` |
| 老師端計時 | 本地 `elapsedSeconds`，remote join 起算 | 同上，純顯示 | `TeacherAgoraManager.swift:92,378` |
| 斷線偵測 | `.connectionLost` 無發送來源（未接線） | 斷線不影響計費，無暫停/補時 | `AgoraEngineWrapper.swift` 註解 |

**結論**：計費區間 `[接受時間, /end 呼叫時間]` 與「學生實際看到老師的時間」**毫無對應關係**，是爭議的溫床。

---

## 2. 核心問題：什麼時間「該算錢」？

「話家常算不算？」這類爭議的根源是**沒有定義可計費區間（billable window）**。業界對即時人對人服務的共識是：

> **計費 = 雙方都在線且可互動的時間（dual-presence）**，與談話內容無關。

也就是說——**話家常本來就在已付費的時段內，它算錢**；要管理的不是「內容是不是教學」，而是：
1. 起點/終點要**客觀可稽核**（不靠任一方良心）。
2. **技術性中斷**（斷線、掛機）不該讓用戶付錢。
3. 給**明確上限與自動結束**，避免無限延長爭議。
4. 留**完整事件軌跡**，爭議時有據可查。

把「教學品質/閒聊」交給**事後評價與退費爭議流程**處理，而不是塞進即時計時器——這是降低爭議的關鍵心法。

---

## 3. 業界做法對照

| 模式 | 代表 | 計費區間錨點 | 適合場景 | 取捨 |
|---|---|---|---|---|
| **雙方在場計費**（dual-presence metered） | Twilio Video / Agora 用量、線上家教（italki/Cambly） | 雙方都 join 頻道 → 任一方離開 | 1v1 即時互動 | 最公平，但需可靠的 presence 事件 |
| **預付時段包**（prepaid block） | Cambly 15/30 分課、電話諮詢 | 預扣 N 分鐘，用完自動結束 | 時長固定的課 | 簡單、爭議少；超時需加購 |
| **逐分計費 + 寬限** | 電話客服、法律/醫療諮詢熱線 | 接通起算，每分鐘扣，斷線寬限 | 時長不定 | 彈性高；需防 1 秒逃費（最低消費） |
| **RTC 用量對帳** | Agora Usage API / Webhook（NCS） | 以 RTC 廠商記錄的 channel 在席時長為準 | 任何 Agora 應用 | 第三方權威數據，最難造假；有回報延遲 |
| **伺服器權威時鐘 + 客戶端心跳** | Zoom 計費、雲遊戲計時 | server 記 connect/heartbeat/disconnect | 需防客戶端竄改 | 業界主流；本專案建議採用 |

**共通的防爭議手法：**
- **起點 = 雙方都在線**（不是「撥出」也不是「接受」）。
- **斷線寬限（grace）**：短暫掉線（如 < 30s）不停錶、自動重連；超過則暫停計費或結束。
- **最低消費（minimum charge）**：避免極短時間逃費。
- **計費上限 + 自動結束**：到達已付時長自動進寬限再結束（本專案 iOS 已有 `gracePeriod` 雛形）。
- **取整規則公開**（向上/向下/四捨五入到分鐘），寫進條款。
- **不可竄改的審計日誌**：所有 presence/心跳事件落庫，爭議時重建時間線。

---

## 4. 建議方案：後端權威時鐘 + 雙方在場 + 心跳/RTC 對帳

### 4.1 計費區間定義

```
billable_start = 雙方都進入頻道的時刻（dual-presence）
billable_end   = 任一方離開 / 到達已付時長 / 斷線超過寬限
billable_sec   = Σ(雙方同時在線的區間) − 斷線扣除
最終收費 = clamp(billable_sec, 最低消費, 已付時長)   // 預付包模式不超賣
```

- **話家常**：落在 billable window 內 → **計費**（產品條款需明示「配對成功接通後即計費」）。
- **接通失敗 / 從未 dual-presence**：billable_sec = 0 → 全額退（轉 [cancellation-and-fees.md](./cancellation-and-fees.md) 的 `/cancel`）。

### 4.2 後端：成為唯一計時權威

新增/修改欄位（`appointments`）：

| 欄位 | 意義 | 由誰寫 |
|---|---|---|
| `connected_at` | **雙方都在線**的時刻（真正計費起點） | 後端，收到雙方 presence 後 |
| `last_heartbeat_at` | 最近一次雙方在線心跳 | 後端，每次心跳更新 |
| `disconnected_sec` | 累計斷線扣除秒數 | 後端 |
| `actual_end_time` | 結束時刻 | 後端，`/end` 或逾時清掃 |

**用 RTC 事件當權威起點**（兩條來源擇一或並用）：

```js
// 來源A：客戶端回報「我接通了對方」（雙方各報一次，後端取「兩邊都報到」的時刻）
// POST /call/session/:id/connected   body: { role: 'student'|'teacher' }
function onConnected(appt, role) {
  appt[`${role}_connected_at`] = now();
  if (appt.student_connected_at && appt.teacher_connected_at && !appt.connected_at) {
    appt.connected_at = now();              // ← 真正計費起點，取代 sessionMatcher.js:198 的 accept 起點
    setStatus(appt, 'in_progress');         // ← 補上一直沒被設定的 in_progress
  }
}

// 來源B（更權威、防竄改）：Agora Webhook / Usage API 對帳
// Agora NCS 推 channel join/leave 事件 → 以廠商記錄的在席時長覆核客戶端回報
```

**結算改以 `connected_at` 為準**（取代 `actual_start_time`）：

```js
// routes/call.js  POST /session/:id/end（示意）
const start = appt.connected_at;               // 不再用 accept 時間
if (!start) return releaseHold(appt);          // 從未 dual-presence → 全退
const grossSec = (Date.now() - new Date(start)) / 1000 - appt.disconnected_sec;
const billableSec = clamp(grossSec,
                          cfg.minimumChargeSec,            // 最低消費
                          appt.base_duration * 60);        // 不超賣已付時長
settle(appt, billableSec);                      // 依 billableSec 換算寶石、拆帳、寫帳本
```

### 4.3 客戶端：回報接通 + 心跳，停止當權威

iOS（`CallUseCase`）與老師端皆然——客戶端只**回報事實**，不自己算錢：

```swift
// 進 .connected 時回報一次（後端據此判定 dual-presence）
case .connected:
    startCountdown()                                  // 本地倒數僅供 UI
    Task { try? await repository.reportConnected(sessionId: sessionId) }

// 通話中每 N 秒心跳（讓後端知道「還在線」，斷線可被偵測）
private func heartbeat() async {
    try? await repository.heartbeat(sessionId: sessionId)   // POST /session/:id/heartbeat
}
```

- 本地倒數計時器（`CallUseCase.tick()`）**降級為純 UI**，最終收費以後端為準。
- 心跳停止（超過寬限）→ 後端累加 `disconnected_sec` 或結束 session。

### 4.4 斷線與超時處理

| 情況 | 處理 | 對應機制 |
|---|---|---|
| 短暫斷線（< grace，如 30s） | 不停錶，等重連；超過才累計 `disconnected_sec` | 心跳缺漏偵測 |
| 一方長時間掛機/離線 | 寬限後自動結束，依已計 billable 結算 | 逾時清掃（見 cancellation-and-fees.md §3.3） |
| 到達已付時長 | 進 `gracePeriod`（iOS 已有雛形）→ 提示加購或自動結束 | `ConnectionState.gracePeriod` |
| App 全程沒打 `/end` | 後端逾時清掃以 `connected_at + base_duration` 上限結算 | 兜底 |
| 加購延長 | `/session/:id/extend` 凍結增量寶石、延長上限 | `call.js:450-534`（已存在，需與新計時對齊） |

### 4.5 審計軌跡（爭議的最終依據）

每個 session 落一張事件表（append-only），爭議時可重建時間線：

```
session_events(session_id, ts, actor, event, meta)
  event ∈ { offered, accepted, student_connected, teacher_connected,
            heartbeat, disconnected, reconnected, grace_entered,
            extended, ended, cancelled, auto_swept }
```

- 計費爭議時，以 `connected_at`、心跳序列、Agora Usage 對帳三者交叉佐證。
- 三者出現分歧時，**以 Agora 廠商記錄為最終權威**（第三方、難造假）。

---

## 5. 建議落地順序

1. **先止血**：後端結算改用「雙方在場」起點而非 accept 起點（§4.2），並補 `in_progress` 狀態——這一步直接修正「超收」與「不知道有沒有接通」。
2. **補回報**：iOS/老師端加 `reportConnected` + `heartbeat`（§4.3）。
3. **補兜底**：逾時清掃 + 斷線寬限（§4.4），解決「沒人打 /end」與「斷線照收費」。
4. **補對帳**：接 Agora Webhook/Usage 覆核（§4.2 來源B），作為最終權威。
5. **補軌跡**：`session_events` 審計表（§4.5）。
6. **訂條款**：計費起點、取整、最低消費、寬限秒數寫進用戶條款並集中 config。

---

## 6. 待辦清單

- [ ] 後端：新增 `connected_at` / `last_heartbeat_at` / `disconnected_sec`，結算改以 `connected_at` 為起點。
- [ ] 後端：dual-presence 判定 + 正式設定 `in_progress`。
- [ ] 後端：`POST /session/:id/connected`、`POST /session/:id/heartbeat` 端點。
- [ ] 後端：接 Agora Webhook / Usage API 對帳，分歧時以廠商為準。
- [ ] 後端：`session_events` append-only 審計表。
- [ ] 後端：斷線寬限 + 逾時清掃結算（與 cancellation 兜底共用）。
- [ ] iOS：`.connected` 回報 + 通話中心跳；本地計時降級為純 UI。
- [ ] 老師端：同步回報接通 + 心跳 + 呼叫 `/end`。
- [ ] 全域：計費起點/取整/最低消費/寬限集中 config，並寫入用戶條款。

---

## 附：計費時間線（目標狀態）

```
accept ───(空窗,不計費)───▶ student_connected ┐
                                               ├─▶ connected_at = 雙方在線(計費起點, status=in_progress)
                            teacher_connected ─┘        │
                                                        │  ◀── 心跳每 N 秒；斷線>grace 累加 disconnected_sec
                                                        ▼
                                          到達已付時長 → gracePeriod → 自動結束
                                                        │
                                          任一方離開 / /end / 逾時清掃
                                                        ▼
                          billable = (end − connected_at) − disconnected_sec
                          收費 = clamp(billable, 最低消費, 已付時長)   ←—— 與 Agora Usage 對帳
```
