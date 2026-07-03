# 活動報名 (campaign join) 路徑三方不符

- 首次發現:2026-07-01(`2026-07-01-endpoints.md` 事實層 🟡「只有 iOS」#1)
- 嚴重度:🔴 高 —— iOS 報名功能線上實際 404
- 影響範圍:iOS + Backend
- 方向:**新規劃待決定**(路徑要收斂到哪個),但 iOS 端已壞需儘快
- 狀態:待雙邊拍板

## 功能

「報名參加活動」,專給 **CAPACITY(人數限定)** 類型活動:使用者按報名 → 後端在交易鎖內
確認活動進行中 + 類型為 CAPACITY + 未重複報名 + **名額未滿(`FOR UPDATE` 防併發搶名額)**
→ 寫入 `campaign_participant`、`camp_vl_current_capacity + 1`。
其他類型不需手動報名(`PRIZE_POOL`/`NEW_USER` 上傳產品自動觸發;`GENERAL`/`LEVEL`/`BRAND` 免報名)。

## 事實(三方打架)

| 方 | 路徑 | 狀態 |
|---|---|---|
| iOS | `POST /campaign-join/:id` (`sevena/Services/CampaignAPIClient.swift:210`) | 呼叫中 |
| 後端 A | `sevena-backend/routes/join-campaigns.js:33` `POST /:id` | **檔案存在但 `index.js` 未 `app.use` 掛載** → 線上不存在 |
| 後端 B | `sevena-backend/routes/campaign.js:349` `POST /campaign/:id/join` | **已掛載(`index.js:85` `app.use('/campaign')`)、活著**,邏輯幾乎相同且多了起訖時間檢查(回 `not_started`/`expired`) |

## 判斷

- **iOS 報名功能目前實際壞掉**:它打的 `/campaign-join/:id` 對應到未掛載的 `join-campaigns.js`,線上回 **404**。
- **後端有兩份重複實作**同一個 CAPACITY 報名邏輯,一份沒接上、一份活著。典型「沒先對齊各做各的」。

## 待更新(擇一,需雙邊拍板)

- **(建議)** 留活著且驗證較完整的 `campaign.js` `/campaign/:id/join`:
  - iOS 改打 `POST /campaign/:id/join`;
  - 後端刪除未掛載的 `join-campaigns.js`(否則會一直被稽核當幽靈端點報出)。
- (替代)後端把 `join-campaigns.js` 掛在 `app.use('/campaign-join', ...)`、iOS 不動,並廢掉 `campaign.js` 的 join —— 較不建議,等於捨棄較完整的驗證邏輯。

定案後開 `contracts/campaign-join.md` 立契約。
