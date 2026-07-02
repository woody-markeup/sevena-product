# 1v1 教學串流 — 取消課程與費用處理

> 回推自三端 codebase（`sevena/` 學生、`sevena-teacher/` 老師、`sevena-backend/`）並提出對齊方案。
> 主題：**任一方在「課程開始前 / 剛開始」取消時，如何通知後端、如何處理已預扣的費用。**
> 計時與課中計費爭議見 [time-tracking.md](./time-tracking.md)。

## 一句話

後端**已經有**完整的取消退款端點（`POST /call/session/:id/cancel`，會解凍寶石），但**兩支 App 都沒把這條線接上去**：學生端取消只清本地、不通知後端；老師端整條交易生命週期（accept / decline / cancel / end）全缺。結果是——**配對成功後一旦沒走到正常結束，預扣的寶石會永久凍結、無人釋放。**

---

## 1. 現況（code reality）

### 1.1 費用模型：寶石「凍結 → 扣除 / 解凍」

| 階段 | 動作 | 欄位 / 端點 | 位置 |
|---|---|---|---|
| 預扣 | 凍結寶石（不扣） | `entity.enti_vl_frozen_coins += gemCost` | `routes/call.js:99-102`（`POST /call/request`） |
| 實扣 | 從總額與凍結同時扣 + 拆帳給老師 | `enti_vl_coins -= gemCost; frozen -= gemCost` | `routes/call.js:575-591`（`POST /session/:id/end`） |
| 退款 | 解凍（不扣） | `frozen -= gemCost` + 寫 refund 紀錄 | `routes/call.js:737-769`（`POST /session/:id/cancel`） |
| 自動退 | 無老師可配時解凍 | `failSessionNoTeachers()` | `service/sessionMatcher.js:344-410` |

> ⚠️ 另有一層**未對帳的落差**：iOS 的 `PaymentServiceProtocol.pay()`（站外刷卡 SDK，目前僅 skeleton）與後端的「寶石凍結」是兩套互不相干的金流。本檔聚焦「取消 → 釋放預扣」，刷卡↔寶石的對帳問題另案處理。

### 1.2 後端取消端點 `POST /call/session/:id/cancel`（已實作 ✅）

`routes/call.js:707-810`：

- **誰可取消**：學生（`user_id = entiId`）**或**已配對老師（`mua_id` 比對）——`call.js:722`。
- **可取消狀態**：`matching` / `scheduled` / `pending_teacher` / `matched`——`call.js:732`。
- **不可取消**：`in_progress` / `completed` / `canceled`。
- **退款對象**：一律退給 `appointment.user_id`（學生），**不是 caller**（因 caller 可能是老師）——`call.js:737`。
- 寫 `session_transactions(type='refund')` + `user_transaction(type='session_refund')`，並對雙方發 Live Activity `end` 推播解除鎖屏卡片。

### 1.3 缺口：兩端都沒接

| 端 | 應做的「生命週期取消」 | 現況 | 位置 |
|---|---|---|---|
| 學生 App | 媒合中/連線失敗 → 打 `/cancel` | ❌ `cancelRequest()` 只 `beginTask.cancel()` + 本地 `endSession()`，**不打後端**；`CallRepository` 內**根本沒有 cancel 端點** | `UseCases/CallUseCase.swift:86-92`、`Repositories/CallRepositoryImpl.swift` |
| 學生 App | 連線失敗 → 通知後端 | ❌ `.ended(.failed/.declined)` 分支**什麼都不打**；只有 `.completed` 才呼叫 `/end` | `UseCases/CallUseCase.swift:163-173` |
| 老師 App | accept / decline / cancel / end | ❌ 全缺，`endCall()` 只 `leaveChannel()` 不通知後端 | `TeacherAgoraManager.swift:391` |
| 後端 | `matched` 久未結束的逾時釋放 | ❌ 無（只有「老師接案前」的 30s offer 逾時） | `service/sessionMatcher.js` |

**最危險的後果**：配對成功（`matched`，此時 `actual_start_time` 已被設為 `NOW()`）後若接通失敗，學生端不打任何 API → session 永遠卡在 `matched`、寶石**永久凍結不退**。

---

## 2. 問題分類：取消情境矩陣

把「誰取消 × 在哪個時點」攤開，費用結果才不會打架。建議政策如下（數值為**建議預設**，應收斂進後端單一 config，不寫死於程式各處）：

| # | 取消方 | 時點（session 狀態） | 費用結果 | 通知路徑 |
|---|---|---|---|---|
| A | 學生 | 媒合中（`pending_teacher`，還沒配到） | **全額退**（解凍） | 學生 App → `/cancel` |
| B | 學生 | 已配對、未接通（`matched`，接通前） | **全額退**（見 §4 政策，可設短免費窗） | 學生 App → `/cancel` |
| C | 學生 | 剛接通（`in_progress`，< 免費窗，如 60s） | **全額退** | 學生 App → `/cancel`（需放寬狀態，見 §3.3） |
| D | 學生 | 接通後超過免費窗 | **依實際時長計費** | 走結束流程 `/end`（見 time-tracking.md） |
| E | 老師 | 收到邀約未接（30s 逾時 / decline） | **全額退**（換下一位或無人退款） | 後端 `declineSessionAsTeacher` / `failSessionNoTeachers`（已實作） |
| F | 老師 | 已接受、未接通（`matched`） | **全額退** + 記老師取消率 | 老師 App → `/cancel` |
| G | 老師 | 接通後取消 | **全額退** + 記老師違約 | 老師 App → `/cancel`（需放寬狀態） |
| H | 任一方 | 連線技術性失敗（非主動取消） | **全額退**，不計任一方違約 | 偵測到 `.failed` → 自動 `/cancel`（reason=connection_failed） |

> **核心原則**：iOS/老師端**永遠只呼叫「生命週期操作」（cancel / end），永不自己算錢**。退多少、計不計違約，全由後端依 `cancel reason` + session 狀態決定。這與 `sevena` 既有 spec（`call-payment`：iOS SHALL NOT 呼叫 refund/void）一致。

---

## 3. 對齊方案（程式碼處理）

### 3.1 學生 App：補 `cancelSession` 並接到所有終止分支

`Domain/Protocols/CallRepositoryProtocol.swift` 新增（對齊既有深層協議風格）：

```swift
/// 生命週期取消：通知後端釋放預扣。iOS 不決定退款金額，只送出意圖與原因。
func cancelSession(sessionId: Int, reason: CancelReason) async throws

enum CancelReason: String, Sendable {
    case userCancelledMatching   // 媒合中主動取消
    case userCancelledBeforeCall // 已配對、接通前取消
    case connectionFailed        // 接通失敗（技術性，不計違約）
}
```

`Repositories/CallRepositoryImpl.swift`：

```swift
func cancelSession(sessionId: Int, reason: CancelReason) async throws {
    let body = ["reason": reason.rawValue]
    try await apiClient.post(path: "/call/session/\(sessionId)/cancel",
                             bodyData: try JSONEncoder().encode(body))
}
```

`UseCases/CallUseCase.swift` — 兩個關鍵接線點：

```swift
// (1) 媒合中 / 接通前主動取消（現況只清本地）
func cancelRequest() async {
    beginTask?.cancel()
    await coordinator.endSession()
    if let sessionId = currentSession?.sessionId {
        // 依當前狀態決定 reason
        let reason: CancelReason = connectionState == .matching
            ? .userCancelledMatching : .userCancelledBeforeCall
        try? await repository.cancelSession(sessionId: sessionId, reason: reason)
    }
    await apply(.cancelled)
    await resetState()
}

// (2) 終止事件分流：完成→/end；失敗→/cancel（現況失敗分支什麼都不打）
case .ended(let outcome):
    stopCountdown()
    let sessionId = currentSession?.sessionId
    Task {
        await coordinator.endSession()
        guard let sessionId else { return }
        switch outcome {
        case .completed:
            try? await repository.endCall(sessionId: sessionId)
        case .failed, .declined:
            try? await repository.cancelSession(sessionId: sessionId,
                                                reason: .connectionFailed)
        }
    }
```

> ⚠️ **語意紅線**：失敗時**絕不能**為了「補上通知」而呼叫 `/end`——`/end` 是**實扣**（`call.js:575` 會 deduct + 拆帳），等於對沒接通的課全額收費。失敗一律走 `/cancel`。
> ⚠️ **可靠性**：取消/結束通知不能是 fire-and-forget。現況 `/end` 為 `try?` 不重試，網路抖動就遺失。建議落地一個「待送生命週期事件」本地佇列，App 重啟後補送（見 §5）。

### 3.2 老師 App：補完交易生命週期

教師端目前 0% 接交易線。最小補齊（端點後端皆已存在）：

| 動作 | 端點 | 觸發 UI |
|---|---|---|
| 接受邀約 | `POST /call/session/:id/accept` | 收到 FCM `session_request` → 邀約卡 → 「接受」 |
| 拒絕 | `POST /call/session/:id/decline` | 邀約卡 →「拒絕」/ 30s 自動 |
| 取消（接通前/後） | `POST /call/session/:id/cancel` | 通話前/中「取消課程」 |
| 正常結束 | `POST /call/session/:id/end` | 結束鍵（含時長結算） |

老師端 `cancel` 與學生端同端點，後端已用 `mua_id` 比對放行（`call.js:722`），退款仍回學生。**唯一要加的後端邏輯**：對老師主動取消累計違約率（見 §4）。

### 3.3 後端：兩處強化

**(a) 放寬「接通前剛開始」可取消的狀態。** 目前 `/cancel` 拒絕 `in_progress`（`call.js:732`）。情境 C/G（免費窗內取消）需要能取消已 `in_progress` 的 session 並全額退。建議改為：依 `cancel reason` + 「距 `connected` 時間」判定，而非死板擋 `in_progress`：

```js
// routes/call.js  POST /session/:id/cancel（示意）
const FREE_CANCEL_WINDOW_SEC = cfg.freeCancelWindowSec; // 例如 60，集中 config
const elapsed = appt.connected_at
  ? (Date.now() - new Date(appt.connected_at)) / 1000 : 0;

if (appt.status === 'in_progress' && elapsed > FREE_CANCEL_WINDOW_SEC) {
  // 已超過免費窗 → 不走全額退，導去 /end 依實際時長計費
  return res.status(409).json({ error: 'past_free_window', hint: 'call /end instead' });
}
// 其餘照既有解凍退款流程
```

**(b) `matched` / `in_progress` 久未結束的逾時清掃。** 防止 App 漏打就鎖死寶石。後端跑一個排程（或在 status 輪詢時 lazy 檢查）：

```js
// 偽碼：超過 (base_duration + grace + safety) 仍未結束的 session
// → 自動 /cancel（reason=auto_stale）解凍，或依已連線時長 /end 結算
const STALE_AFTER_MIN = cfg.staleSweepMinutes;
for (const appt of staleMatchedOrInProgress(STALE_AFTER_MIN)) {
  appt.connected_at ? settleByActualDuration(appt) : releaseHold(appt);
}
```

> 此清掃同時是 §1.3「永久凍結」的兜底保險。

---

## 4. 費用政策建議（產品決策項，收斂進後端 config）

| 政策 | 建議預設 | 理由 / 業界對照 |
|---|---|---|
| 免費取消窗（接通後） | 60–120s | 對齊叫車/外送「上車前免費取消」；給雙方確認音訊畫面是否正常的緩衝 |
| 接通失敗（技術性） | 100% 退、雙方皆不計違約 | 非人為，不應懲罰任一方 |
| 學生接通前取消 | 100% 退 | 老師尚未投入服務 |
| 老師接受後取消 | 退學生全額 + **計老師違約率** | 對照網約平台「司機取消率」門檻；違約率過高降配對權重或停權 |
| 學生超過免費窗取消 | 依實際時長計費（最低消費起跳） | 對照諮詢/家教「已開始按分計費」；最低消費避免 1 分鐘逃費 |
| No-show（一方未現身） | 等待上限（如 5 分鐘）後自動取消，可對未現身方計違約 | 對照叫車 no-show fee |

**通用設計準則：**
- **款項只有後端能動**；App 端傳「意圖 + 原因」，金額與違約判定全在後端。
- **取消原因（reason）要進帳本**，作為日後爭議與風控（取消率）的依據。
- **所有秒數/門檻集中單一 config**（對齊 iOS `MatchmakingConfig` 的做法），營運可調不動程式。
- **冪等**：`/cancel`、`/end` 需可重入（重複呼叫不重複退/扣），配合 §3.1 的補送佇列。

---

## 5. 待辦清單

- [ ] iOS：`CallRepositoryProtocol` + `Impl` 新增 `cancelSession(sessionId:reason:)`。
- [ ] iOS：`CallUseCase.cancelRequest()` 與 `.ended(.failed/.declined)` 接 `/cancel`。
- [ ] iOS：生命週期事件本地補送佇列（解決 fire-and-forget 遺失），確保 `/cancel`、`/end` 至少送達一次。
- [ ] 老師 App：補 accept / decline / cancel / end 整條線 + 邀約卡 UI。
- [ ] 後端：`/cancel` 改依 reason + connected 時間判定，支援「免費窗內取消已 in_progress」。
- [ ] 後端：`matched` / `in_progress` 逾時清掃排程（兜底解凍）。
- [ ] 後端：老師主動取消 → 累計違約率欄位 + 風控門檻。
- [ ] 後端：`/cancel`、`/end` 冪等化。
- [ ] 全域：取消窗 / no-show 等門檻集中 config。

---

## 附：取消流程（目標狀態）

```
媒合中(pending_teacher) ──學生取消──▶ /cancel(userCancelledMatching) ──▶ 解凍全退
配到未接通(matched)     ──任一方取消─▶ /cancel(userCancelledBeforeCall) ─▶ 解凍全退
                        ──技術失敗───▶ /cancel(connectionFailed) ────────▶ 解凍全退(不計違約)
接通(in_progress)       ──免費窗內──▶ /cancel ───────────────────────────▶ 解凍全退
                        ──超過免費窗─▶ /end ────────────────────────────▶ 依實際時長實扣(見 time-tracking.md)
無人接受                ──30s×N 逾時─▶ failSessionNoTeachers ──────────────▶ 解凍全退(已實作)
App 漏打                ──逾時清掃───▶ 自動 /cancel 或 /end ─────────────────▶ 兜底釋放/結算
```
