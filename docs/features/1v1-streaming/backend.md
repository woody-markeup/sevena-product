# 1v1 教學串流 — Backend 端 (sevena-backend)

> 回推自 `sevena-backend/` codebase。本檔只記 **後端配對 + 訊令(signaling)**;iOS 學生端見 [ios.md](./ios.md)。

## 一句話

後端是**唯一的 signaling broker**:用配對引擎按相似度自動選線上老師,經 FCM「邀約-接受」牽線,鑄造共用頻道名 `session_<id>` 讓雙方在 Agora 會合。**不是配對碼、也不是分享連結。**

## 連線技術

- 後端**不傳輸媒體**,只負責配對與發頻道資訊。實際視訊走 Agora。
- 頻道名:`channel_name = session_${sessionId}`(`POST /call/request` 建立 appointment 時鑄造)。
- ⚠️ **無 Token 簽發**:`/call/*` 回應一律 `token: null`,全 repo 無 `RtcTokenBuilder` / token route。等同 Agora App ID-only 模式,**上線前須補 Token Server**。

## 關鍵檔案

| 檔案 | 職責 |
|---|---|
| `routes/call.js` | 通話 REST 端點:`/request` `/session/:id/status` `/preview` `/extend` `/end` `/cancel` `/review`、`/teacher/online`、`/teacher/offline`、`/teacher/session/active`、Live Activity token 端點。 |
| `service/matchingEngine.js` | `findBestMatch()` —— 從線上老師排名,加權評分。`PRICING`(15→50/30→100/60→180 寶石)、`PLATFORM_FEE_RATE = 0.20`。 |
| `service/sessionMatcher.js` | 配對狀態機:`offerSessionToTeacher` / `acceptSessionAsTeacher` / `declineSessionAsTeacher` / `tryNextTeacher` / `handleOfferTimeout` / `failSessionNoTeachers`。逾時 in-memory `setTimeout`(`MATCH_OFFER_TIMEOUT_SECONDS`,預設 30s)。 |
| `service/liveActivityPush.js` | iOS Live Activity 推播(`sendInCallUpdate`/`sendTeacherInCallUpdate`/`sendEnd`)。 |
| `routes/notifications.js` | `createNotification()` → FCM 推播。 |

## 配對狀態機

```
學生 POST /call/request
  ├─ 凍結寶石(enti_vl_frozen_coins += gemCost)
  ├─ findBestMatch() 排名線上老師
  ├─ 建 appointment(status=pending_teacher, channel_name=session_<id>)
  └─ offerSessionToTeacher(排名第1) → FCM type:'session_request' 給老師 entity
                                     → armOfferTimeout(30s)
老師端:
  ├─ accept  → acceptSessionAsTeacher → status=matched, actual_start_time=NOW(), 建扣款 row, 發 Live Activity
  └─ decline / 30s timeout → declineSessionAsTeacher → tryNextTeacher(換下一位,排除已拒)
                              └─ 無人 → failSessionNoTeachers(退寶石, status=no_teacher_available, FCM 通知)
學生端輪詢 GET /call/session/:id/status:
  status=="matched" → 回 channel_name + token(null) + teacher_info → iOS join Agora
```

- **非對稱邀約:** 學生丟需求進池,後端逐一 offer,老師有否決權。
- **跨端喚醒:** 老師靠 FCM `session_request` 推播;學生靠 2 秒輪詢 `/status`。無常駐 WebSocket。
- **逾時用 in-memory map**(`pendingTimeouts`):⚠️ 單機狀態,多實例部署會失效。

## 配對評分(matchingEngine,僅取 `is_online=true AND is_suspend=false`)

| 維度 | 權重 | 計算 |
|---|---|---|
| 臉部特徵重疊 | 25 | 9 項特徵(膚質/臉型/眼型…)相同比例 × 25 |
| 產品重疊 | 8 | 與學生相同彩妝品 / 老師持有數 × 8 |
| 完成率 | 7 | completed/(completed+failed)×7;無紀錄給 3.5 |
| 風格重疊 | 5 | style_tags 交集 / 老師風格數 × 5 |
| 評分 | 5 | ratings/5 × 5 |
| 新人加成 | +50 | 已認證 + 30 天內 + 零收入 |

平手:先比 `is_online`,再比 `last_online` 新近度。

## 會員 / 角色資料模型

- `entity` —— **所有人的基底帳號**(firebase_uid、寶石 enti_vl_coins/frozen、等級、名稱、頭像…)。
- `mua_account` —— **老師擴充表**,與 entity 1:1(`enti_cd_id` 外鍵)。**有 mua_account row 即為老師。**`getMuaIdFromUid()` 查無則回 null(非老師)。欄位含 `is_online`/`is_certified`/`is_suspend`/`ratings`/`completed`/`total_earnings` 等。
- `accounts` —— `profile.js` 另查的表(firebase_uid),疑似 legacy/auth,待確認。
- **目前實際鑑權只有 Firebase**(`middleware/auth.js`):驗 Firebase ID token → 取得使用者。學生與老師(若有)都靠 `firebase_uid` → `entity` →(有無)`mua_account` 判定角色。**角色分離在資料層,不在 auth 層。**
- ⚠️ **「App B」分支是 dead code**:`auth.js` 有第二條 `jwt.verify(token, process.env.APP_B_JWT_SECRET)`(原作者註解稱 "App B"),設想未來第二支 app 用共享密鑰 JWT 登入。但 **`APP_B_JWT_SECRET` 在 dev/prod 兩台 EC2 都從未設定**(2026-06-29 上機核實),env 為 `undefined` → 該分支必 throw 被 catch、永不成功;且**無任何後端簽發此 token**(唯一 `jwt.sign` 在 `liveActivityPush.js`,為 APNs 推播 token)。故 App B 為**未接完的預留 scaffold,身分無從指認**,勿當成已上線的老師端鑑權。

## 待辦 / 風險

- ⚠️ 無 Token Server(同 iOS)。
- ⚠️ 逾時計時為單機 in-memory,不適合水平擴展。
- `accounts` 表用途待釐清。
