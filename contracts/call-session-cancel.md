# 契約:取消 1v1 通話 Session

> **single source of truth** —— `POST /call/session/:id/cancel`。
> iOS 學生端缺口 #2(取消/連線失敗不通知後端 → 預扣寶石卡死)應接此既有端點。
> 對照背景見 [docs/features/1v1-streaming/cancellation-and-fees.md](../docs/features/1v1-streaming/cancellation-and-fees.md)。

狀態圖示:✅ 已實作(回推自 `sevena-backend/routes/call.js:707-810`,2026-06-30 核實) · 🟡 提案中(尚未實作,需雙邊對齊後再做)

---

## 端點

| 項目 | 值 |
|---|---|
| Method / Path | `POST /call/session/:id/cancel` ✅ |
| 路徑參數 | `id` = `session_id`(整數) |
| 鑑權 | Firebase ID Token(`Authorization: Bearer <idToken>`,`authenticateFirebase`)✅ |
| 用途 | 生命週期取消:解凍預扣寶石、退款給**學生**、session → `canceled`、解除雙方 Live Activity |

---

## Request

### 目前(✅ 已實作)

**無 body**。後端僅用路徑 `:id` + token 識別呼叫者,不讀任何 request body。

```http
POST /call/session/123/cancel
Authorization: Bearer <firebaseIdToken>
```

- 呼叫者可為**學生**(`appointments.user_id = entiId`)**或已配對老師**(`mua_id` 比對)—— `call.js:717-725`。
- 無論誰呼叫,**退款一律回學生** `appointment.user_id`(老師 `frozen_coins` 為 0,退錯人會 silently no-op)—— `call.js:737-741`。

### 提案擴充(🟡 尚未實作)

為了區分「主動取消 / 接通失敗 / no-show」以驅動退款政策與老師違約率,建議後端加收 `reason`:

```jsonc
// 🟡 提案中 —— 後端目前不讀此 body,加了也會被忽略
{
  "reason": "user_cancelled_matching"
    // ∈ user_cancelled_matching | user_cancelled_before_call
    //   | connection_failed | teacher_cancelled | no_show
}
```

> ⚠️ iOS 若要先行送出 `reason`,**對現況無害但也無效**(後端忽略);要產生行為差異(計違約、免費窗判定)須等後端 🟡 實作。落地細節見 cancellation-and-fees.md §3.3 / §4。

---

## Response

### 200 OK(✅)

```json
{ "success": true, "refunded_gems": 100 }
```

`refunded_gems` = `appointment.gem_cost`(被解凍的寶石數)。

### 錯誤(✅,皆回 JSON `{ "error": "<code>" }`)

| HTTP | `error` code | 意義 | iOS 建議處理 |
|---|---|---|---|
| 404 | `account_not_found` | token 對應不到 entity | 視為登入態異常 |
| 404 | `session_not_found` | session 不存在,或呼叫者非該 session 的學生/老師 | 視為已結束,清本地狀態 |
| 400 | `cannot_cancel_active_session` | 狀態不在可取消集合(見下) | **見冪等說明** |
| 500 | `<err.message>` | 伺服器/DB 錯誤(交易已 ROLLBACK) | 重試(配合補送佇列) |

---

## 可取消狀態(✅)

僅這四個狀態可取消 —— `call.js:732`:

```
matching · scheduled · pending_teacher · matched
```

- `in_progress` / `completed` / `canceled` → 回 **400 `cannot_cancel_active_session`**。
- ⚠️ 因此「**剛接通就想全額取消**」(cancellation-and-fees.md 情境 C/G)目前**做不到** —— 需後端 🟡 放寬(依 `reason` + 免費窗判定),否則只能走 `/end`(實扣)。

---

## 後端副作用(✅,單一 DB transaction,`call.js:715-783`)

呼叫成功時,後端在一個 transaction 內完成:

1. 解凍學生寶石:`enti_vl_frozen_coins -= gem_cost`(退學生)。
2. `appointments.appointment_status → 'canceled'`。
3. 寫 `session_transactions(transaction_type='refund', status='completed')`。
4. 寫 `user_transaction(tran_tx_type='session_refund', status='completed', ref='session_<id>_cancel')`。
5. 把 `/request` 時建立的 pending 付款 `user_transaction` 標為 `'rejected'`。
6. `matched_result_logs.status → 'aborted'`。
7. `clearOfferTimeout(sessionId)`(清 in-memory offer 計時)。
8. 對學生 + 老師發 Live Activity `sendEnd`(解除鎖屏卡片;失敗只 log 不擋流程)。

---

## 冪等性(✅ 現況行為,非設計保證)

- **不會重複退款**:第一次成功後 status 已是 `canceled`,第二次呼叫落入 400 `cannot_cancel_active_session`,不會再次解凍。
- 但**第二次回 400 而非 200**,iOS 補送/重試邏輯應把 `cannot_cancel_active_session` 與 `session_not_found` **視為「已取消成功」**(終態),不要當失敗無限重試。
- 🟡 若未來要真正冪等(重複呼叫回 200),需後端對「已 canceled」回 success。

---

## iOS 接線對應(建議)

```swift
// Domain/Protocols/CallRepositoryProtocol.swift
func cancelSession(sessionId: Int, reason: CancelReason) async throws

enum CancelReason: String, Sendable {           // 對齊上方 🟡 reason 列舉
    case userCancelledMatching   = "user_cancelled_matching"
    case userCancelledBeforeCall = "user_cancelled_before_call"
    case connectionFailed        = "connection_failed"
}

// Repositories/CallRepositoryImpl.swift
func cancelSession(sessionId: Int, reason: CancelReason) async throws {
    // 現況後端忽略 body;先帶著 reason 以利日後對齊(無害)
    let body = try JSONEncoder().encode(["reason": reason.rawValue])
    try await apiClient.post(path: "/call/session/\(sessionId)/cancel", bodyData: body)
}
```

接線點(`UseCases/CallUseCase.swift`):
- `cancelRequest()`(:86-92)—— 媒合中/接通前主動取消。
- `.ended(.failed/.declined)`(:163-173)—— 連線失敗,`reason = connection_failed`。
- **紅線**:失敗**不可**改打 `/end`(`call.js:537-680` 是實扣+拆帳,等於對沒接通的課全額收費)。

---

## ⚠️ 與此契約相鄰、目前仍缺的後端能力(🟡,非本端點)

| 缺口 | 影響 | 追蹤 |
|---|---|---|
| `/cancel` 不支援 `in_progress` 免費窗取消 | 剛接通無法全額退 | cancellation-and-fees.md §3.3 |
| `matched`/`in_progress` 無逾時清掃 | iOS 漏打就鎖死凍結 | cancellation-and-fees.md §3.3(b) |
| 無「真正接通」訊號,`actual_start_time` 設在老師接受時 | 計費起點偏早、無法判定接通失敗 | time-tracking.md §4.2 |
| 老師主動取消未計違約率 | 風控缺 | cancellation-and-fees.md §4 |

---

## 變更紀錄

| 日期 | 變更 | 狀態 |
|---|---|---|
| 2026-06-30 | 首次回推既有 `/cancel` 行為立契約;標記 `reason` 擴充與 `in_progress` 免費窗為提案 | ✅ 現況 + 🟡 提案 |
