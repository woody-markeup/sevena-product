# 契約:1v1 通話 — iOS 預建流程與預先假設之 API 調整規格

> **用途** —— iOS 學生端(`sevena/`)在後端尚未提供對應能力前,已**先以 protocol + mock 把整條 1v1 流程建好**,並對後端 API 做了一批**預先假設**。本檔把這些假設一次攤平成單一清單,作為**拿去跟後端拍板**的 single source of truth。
>
> 對照背景:[docs/features/1v1-streaming/ios.md](../docs/features/1v1-streaming/ios.md)(iOS 現況)、[call-session-cancel.md](./call-session-cancel.md)(取消契約,已立)、iOS 主線規劃 `sevena/openspec/changes/student-1on1-call-flow/`、待確認清單 `sevena/PENDING_CONFIRMATIONS.md`。
>
> 狀態圖示:✅ 後端已實作且對齊 · 🟡 iOS 先做/後端現忽略(additive,無害) · 🔴 不對齊即壞(阻斷) · ⚪️ 假設之新端點,後端尚無

---


iOS 已把「發起 → 找人 → 配對 → 接通 → 通話 → 互評」整條流程連同**付款 / 媒合 / 計時 / 生命週期取消**四個抽象接縫做完(MVP 以 mock 頂替),對後端的假設分兩種:**(A) additive 欄位**——後端現忽略、加了無害、iOS 零改動即對齊;**(B) 阻斷或待新增**——不對齊 App 就壞或功能缺。**目前唯一會直接壞掉的是 `/call/pricing`(§3.3,🔴 解碼必失敗)。**

---

## 1. iOS 預建流程總覽(哪些已建好、以什麼頂替)

| 流程段 | iOS 已建 | 後端依賴 | 現況頂替 | 子變更(已 archive) |
|---|---|---|---|---|
| 付款(服務費 + 小費) | `PaymentServiceProtocol.pay(amount)` 薄抽象;站外 Apple Pay、幣別中性;iOS **不碰** authorize/capture/void/refund | 金額來源 `fetchPricing`、真實收款/對帳端點 | `MockPaymentService`(DEBUG_TOOLS);prod 骨架回 `.failed` 杜絕假成功 | `call-payment` |
| 媒合 | `Matchmaker` 契約(events 流 + `MatchResult`)、狀態槽 auto-pass、`SessionDeadlineProvider`(180s/20s) | matched 回傳 token/channel/uid/teacher;未來 accept/decline | `PollMatchmaker`(= 現有 2s 輪詢 `/status`);LocalTimer 計時 | `call-matchmaking` |
| 發起表單 | 主題/步驟/風格/備註 + 站外費用顯示 | `/call/request` 收媒合標籤;`fetchPricing` 幣別中性 | 標籤 additive 送出(後端忽略);pricing 見 §3.3 | `call-request-form-completion` |
| 生命週期取消 | `cancelSession(reason:)` + 終態冪等 + 補送佇列;失敗走 `/cancel` 不誤打 `/end` | `/cancel` 收 `reason`;in_progress 免費窗;逾時清掃 | `reason` additive 送出(後端忽略) | `call-lifecycle-cancellation` |
| 評分 + 小費 | `CallReviewScreen` 星等 + 小費(獨立雙路徑) | `/review`;tip 收款端點 | rating/comment 送後端;tip 走 `pay()`(mock)**未進後端** | `call-review-tip` |
| 計時 | 本地倒數(純 UI)、grace period 雛形 | 後端權威計時、`connected`/`heartbeat` 回報 | `NoopCallTimekeeping`;本地倒數 | (roadmap §7,骨架先行) |
| 斷線 | 偵測 → `.connectionLost` → `.ended(.failed)` → `/cancel` | (同取消) | 斷線即結束返首頁(無獨立 toast) | `call-lifecycle-cancellation` §5 |

> **設計紅線(貫穿全流程):** iOS/老師端**只送「生命週期意圖 + 原因」,永不自己算錢**。退多少、計不計違約,全由後端依 `reason` + session 狀態決定。對齊 `call-payment` spec「iOS SHALL NOT 呼叫 refund/void」。

---

## 2. 預先假設的 API 調整 — 總表

| # | 端點 | 假設調整 | 後端現況 | 類型 | 阻斷性 | §  |
|---|---|---|---|---|---|---|
| 1 | `POST /call/request` | 收 `makeup_steps` / `style_refs` / `custom_topic` / `note` | 現忽略 | 🟡 additive | 無(無害) | §3.1 |
| 2 | `POST /call/session/:id/cancel` | 收 `reason` 列舉 | 現忽略 | 🟡 additive | 無(行為差異待後端) | §3.2 |
| 3 | `GET /call/pricing` | 回 `{ duration, amount, currency }` | 回 `{ duration, gem_cost, platform_fee, mua_payout }` | 🔴 schema 不符 | **高——解碼必失敗** | §3.3 |
| 4 | `GET /call/session/:id/status` | `token` 為真實 Agora token;`teacher_info` 全欄 | `token: null`;`teacher_info` 已回 | 🔴 token / 🟡 teacher | 中(啟用憑證即失敗) | §3.4 |
| 5 | `POST /call/session/:id/review` | (可能)收 `tip` 金額 | 只收 `rating`+`comment` | ⚪️ 未定 | 低(tip 另走 `pay()`) | §3.5 |
| 6 | 配對 accept/decline | `POST /session/:id/accept`·`/decline` | 後端**已有**(見 alignment) | ⚪️ iOS 未接 | 低(MVP auto-pass) | §3.6 |
| 7 | 接通/心跳回報 | `POST /session/:id/connected`·`/heartbeat` | 無 | ⚪️ 新端點 | 中(計費爭議) | §3.6 |
| 8 | 小費收款 / 對帳 | 服務商 SDK + 收款端點 | 無 | ⚪️ 新端點 | 中(prod 收不到款) | §3.6 |
| 9 | Agora Token Server | 簽發 RTC token 端點 | 無 | ⚪️ 新端點 | 中(啟用憑證即失敗) | §3.6 |
| 10 | 通話輪盤即時聯動 | 老師選品經 **Agora Data Stream** 即時帶動學生輪盤(非 REST、後端不轉送) | 不在熱路徑,無需端點 | ✅ Data Stream(定案) | 無(後端);teacher 端待實作發送方 | §3.7 |

---

## 3. 逐端點規格

### 3.1 `POST /call/request` — 媒合標籤(🟡 additive)

iOS 已在發起 body 內**選擇性附帶**媒合標籤;空集合不送(`CallRepositoryImpl.swift:29-45`)。後端現忽略,加了無害;日後實作媒合採用時 iOS 零改動即對齊(比照 `CancelReason`)。

```jsonc
POST /call/request
{
  "topic_id": 12,            // ✅ 現有
  "duration": 30,            // ✅ 現有(分鐘)
  "style_id": 3,             // ✅ 現有(選填;無 picker 時省略)
  // ↓ 🟡 iOS 先送、後端現忽略(additive)
  "makeup_steps": [101, 102],          // MakeupStepSub.mastCdId 陣列
  "style_refs": {                       // 「Styles you like」風格參考
    "post_ids": [55, 56],
    "product_ids": [88]
  },
  "custom_topic": "婚禮妝",             // 主題選 Other 時的自訂文字
  "note": "想加強眼影"                  // 給藝術家備註
}
```

- iOS 對應:`CallRequestTags`(`Models/CallModels.swift`)。
- **待後端**:媒合演算法採用這些標籤時,雙邊確認欄位命名(snake_case)與型別。`style_refs.product_ids` 的「可當風格參考的產品」資料源後端尚缺(見 PENDING styles picker)。

### 3.2 `POST /call/session/:id/cancel` — `reason`(🟡 additive)

**已於 [call-session-cancel.md](./call-session-cancel.md) 立契約**,此處只索引。iOS 已送 `{ "reason": <code> }`(`CallRepositoryImpl.swift:60-70`),後端現忽略。列舉(`Domain/Call/CancelReason.swift`):

```
user_cancelled_matching | user_cancelled_before_call | connection_failed
```

- 要產生行為差異(計違約、免費窗判定)須等後端實作(cancellation-and-fees.md §3.3/§4)。
- iOS 已把終態碼(`cannot_cancel_active_session` 400 / `session_not_found` 404)視為**取消成功**、不重試(冪等段)。

### 3.3 `GET /call/pricing` — 幣別中性(🔴 阻斷,現況解碼必失敗)

**這是目前唯一會直接壞掉的不一致。**

| 面 | 形狀 | 來源 |
|---|---|---|
| iOS 期望 | `{ duration: Int, amount: Decimal, currency: String }`(皆非 optional) | `CallPricingResponse`(`Models/CallModels.swift:30`) |
| 後端現回 | `{ duration, gem_cost, platform_fee, mua_payout }` | `sevena-backend/routes/call.js:58` |

→ **欄位不符,`fetchPricing()` 必拋解碼錯誤。** 後果:`CallTopUpSheet` 顯示「Pricing unavailable」、grace period 加時靜默無反應、發起表單費用列取不到值。**定價 schema 未對齊前,凡依賴 pricing 的路徑(加時、費用顯示)全程不可用。**

**建議定案(擇一):**
- (a) 後端 `/call/pricing` 改回幣別中性 `{ duration, amount, currency }`(對齊站外現金金流,gem 計價汰除);或
- (b) 雙邊拍板保留欄位並讓 iOS 相容解碼。

> iOS 已全面改站外付款(幣別中性,Apple 3.1.3(d)),故傾向 (a)。金額/幣別 App 不寫死,一律依此端點。**優先序最高。**

### 3.4 `GET /call/session/:id/status` — token + teacher_info

```jsonc
GET /call/session/:id/status
{
  "status": "matching|matched|declined|...",  // ✅
  "token": null,           // 🔴 後端固定回 null;iOS 以 nil join
  "teacher_info": {        // 🟡 已回,但 CallScreen 通話中未顯示
    "id": 1, "name": "Maddy", "avatar_url": "...", "ratings": 4.5
  },
  "uid": 10023             // ✅ 學生 entity id
}
```

- **`token: null`(🔴 條件性阻斷)**:Agora 專案若啟用 App Certificate,`joinChannel(byToken: nil)` 會失敗、主視訊接不上;testing 模式(無憑證)才可用 null。上線前須接 Token Server(§3.6)。
- **`teacher_info`(🟡)**:資料已在手、存入 `CallingInfo.teacherInfo`,但 `CallScreen` 通話畫面**不顯示**老師姓名/頭像(僅 `CallReviewScreen` 用到)。待設計確認通話中是否呈現 + 版位(PENDING)。

### 3.5 `POST /call/session/:id/review` — 小費(⚪️ 未定)

iOS 現況只送 `{ rating, comment }`(`CallRepositoryImpl.swift:86-90`);**小費不走 `/review`**,而是評分頁內獨立走 `PaymentServiceProtocol.pay()`(目前 mock)。兩者為視覺一顆 Submit、底層雙路徑(tip 失敗不擋評分)。

**待後端定案:**
- 小費是否併入 `/review`(帶 `tip` 金額)還是獨立收款端點?
- 小費級距目前為 MVP 暫代(依 base `amount` 衍生 10/15/20%);後端是否回傳專屬 tip 級距 + 幣別?

### 3.6 假設之新端點(⚪️ 後端尚無 / iOS 未接)

| 端點 | 用途 | 後端狀態 | iOS 狀態 | 追蹤 |
|---|---|---|---|---|
| `POST /call/session/:id/accept`·`/decline` | 配對後老師接受/拒絕 | **已有**(`call.js:1095/1128`) | 未接(MVP auto-pass,不渲染挑人頁) | alignment endpoints #5/#6 |
| `POST /call/session/:id/connected` | 回報「雙方接通」→ 後端定 `connected_at`、設 `in_progress` | 無 | 未接(計時暫本地) | time-tracking.md §4.2 |
| `POST /call/session/:id/heartbeat` | 通話中心跳,斷線偵測/暫停計費 | 無 | 未接 | time-tracking.md §4.3 |
| 小費收款 / 對帳端點 | 服務商 SDK 收款 | 無 | `MockPaymentService`;prod 骨架 `.failed` | PENDING call-payment |
| Agora Token Server | 簽發 RTC token(§3.4) | 無 | 以 `token: nil` join | ios.md 待辦 |

> **配對 accept/decline 特例**:後端已實作、iOS 未接。MVP 照 PM(MUA 接案、用戶不挑人、狀態槽 auto-pass),故 iOS 端**刻意不接**;未來開「用戶挑人」時換 `ClientPicksMatchmaker` + 渲染資訊頁即可,狀態機已保留接縫。

### 3.7 通話輪盤即時聯動(✅ iOS 學生端已實作 · 發送方交接 teacher 端 · 後端不在熱路徑)

通話中的三層彩妝輪盤(轉盤),其「顯示/選中哪個產品」**來自 1v1 對話中老師端的即時操作**——老師在通話裡選產品/步驟,學生輪盤即時連動。**這是即時同步問題,不是資料拉取問題,亦非後端 REST 端點。**

**iOS 定案(已 apply + archive:`remote-controlled-wheel`,spec `remote-wheel-control`,2026-07-03):**
- **傳輸 = Agora RTC 內建 Data Stream**(非 RTM/SEI):riding 既有 `AgoraRtcKit` 連線,**不引入新 SDK / token / login**;`createDataStream(ordered:true, syncWithAudio:false)` + `sendStreamMessage`。控制指令與影音「大致同步」即可,不綁 frame。
- **方向 = 老師端(發送)→ 學生端(唯讀接收)**。**學生端接收側 iOS 已完整實作**:`receiveStreamMessageFromUid` → 解碼 → 沿既有 `AsyncStream<CallEvent>` 上浮 `.remoteWheelCommand`(不另建平行流);解碼失敗**忽略不 crash**。以單調遞增 `version` 去重/失序容錯(忽略 `version <=` 已套用者),Data Stream `ordered:true` 之上再加應用層防護(斷線重連遲到不回捲)。
- **後端不在熱路徑**:指令為通話內 peer-to-peer(Agora),後端不轉送、不需新端點。產品識別沿用既有後端 catalog 穩定 id(`maprCdId`),兩端引用同一份即可。

**→ 給 teacher 端(`sevena-teacher`)的交接:發送方對稱實作。** iOS 側僅留 send-only 骨架(`RealtimeControlChannelProtocol.send` / `AgoraControlChannel`)供本地 loopback;**真實發送在 teacher 端**,須以相同 wire schema 從 Data Stream 送出:

```jsonc
// WheelControlCommand —— 小體積 JSON(Codable),經 Agora Data Stream 送出
{
  "version": 3,              // 單調遞增 Int;接收端忽略 version <= 已套用者
  "category": "EYESHADOW",   // layer1:MakeupCategory rawValue;null = 不改分類
  "productId": 12345,        // layer2:MakeupProduct.maprCdId(後端穩定 id);null = 不改產品
  "colorIndex": 0            // layer3:產品調色盤內序 index;null = 不改色號
}
```

- **選取用穩定識別子而非純陣列 index**(降雙邊清單漂移):分類用 `MakeupCategory` rawValue、產品用後端 `maprCdId`;僅色號因無獨立穩定 id 用 palette order index。
- teacher 端須:`createDataStream` + 每次選取變更 `sendStreamMessage`(version+1);與 iOS 接收端行為對稱。

**⚠️ 待跨 repo 對齊(唯一未結項):**
- **wire schema 與「id vs index」最終拍板** —— teacher 端發送格式須與上表逐欄一致;色號用 index 的漂移風險雙邊確認(見 `sevena/PENDING_CONFIRMATIONS.md`)。
- 「初始/當前選中」狀態補償(晚接通或斷線重連時如何拿到當前選中):目前靠 teacher 端重送最新 command;是否需要一次快照補償由雙邊定。
- **本項不需後端動作**;僅 iOS ✅ ×已完成 + teacher 端待實作發送方。

---

## 4. 阻斷性優先序(拿去跟後端談的順序)

1. **🔴 `GET /call/pricing` 幣別中性(§3.3)** —— 唯一會直接壞的,加時/費用顯示全掛。**先修這個。**
2. **🔴 Agora Token Server / `status.token`(§3.4)** —— 啟用 App Certificate 後主視訊接不上;上線前必補。
3. **⚪️ 計時對齊 `connected`/`heartbeat`(§3.6)** —— 現以「老師接受」為計費起點會超收,爭議大;後端主導。
4. **⚪️ 小費收款端點(§3.5/§3.6)** —— prod 收不到款(骨架回 `.failed`);服務商 SDK 選型待決。
5. **🟡 `/request` 標籤、`/cancel` reason(§3.1/§3.2)** —— additive 無害,後端有空再收,iOS 零改動。

> **不佔後端序:通話輪盤即時聯動(§3.7)** —— iOS 學生端已定案並實作(Agora Data Stream,唯讀接收);**後端不在熱路徑、無需端點**。剩發送方由 **teacher 端(`sevena-teacher`)** 對稱實作 + 雙邊 wire schema 拍板。

---

## 5. 與既有文件的關係

- **本檔** = iOS 預先假設的**橫向總覽**(一次看完所有端點差異)。
- [call-session-cancel.md](./call-session-cancel.md) = `/cancel` 單一端點的**縱向完整契約**(request/response/副作用/冪等)。
- [docs/features/1v1-streaming/cancellation-and-fees.md](../docs/features/1v1-streaming/cancellation-and-fees.md) / [time-tracking.md](../docs/features/1v1-streaming/time-tracking.md) = 取消/計費的**方案論證**。
- [alignment/2026-07-01-endpoints.md](../alignment/2026-07-01-endpoints.md) = 兩邊端點面的**事實 diff**(自動產生)。
- `sevena/PENDING_CONFIRMATIONS.md` = iOS 端**待拍板清單**(產品/後端/設計)。

---

## 變更紀錄

| 日期 | 變更 | 狀態 |
|---|---|---|
| 2026-07-03 | 首次彙整 iOS 預建流程 + 9 項預先假設 API 調整,標阻斷性優先序 | 🟡 待後端對齊 |
| 2026-07-03 | 補 #10 通話輪盤即時聯動(§3.7):老師通話中操作即時連動學生輪盤,走 RTC data stream/RTM 或 WS(非 REST);iOS 現無即時通道 | ⚪️ 待三方對齊 |
| 2026-07-03 | §3.7 補 Agora 三通道(RTM / Data Stream / SEI)選型比較 | (見下,已被取代) |
| 2026-07-03 | §3.7 定案:iOS 學生端已實作**輪盤即時聯動**(選型 = **Agora Data Stream**,非 RTM;唯讀接收 `.remoteWheelCommand`)。改寫為 teacher 端發送方交接(附 `WheelControlCommand` wire schema);後端不在熱路徑、無需端點。對應 iOS `remote-controlled-wheel`(spec `remote-wheel-control`) | ✅ iOS 學生端完成 · ⚪️ teacher 端發送方待實作 |
