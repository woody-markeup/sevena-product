# 前後端對齊稽核 — 事實層

> 由 `.claude/skills/run-sevena-product/audit.py` 自動產生,**每次執行會覆蓋**。只列事實,不下判斷。
> 判斷(誰先做 / 待更新 / 新規劃待決定)請寫進同資料夾的 `2026-07-01-findings.md`,那份不會被覆蓋。

- 產生日期:2026-07-01
- 後端端點:159 條 · iOS 端點:69 條 · 契約:1 份

## 🔴 只有後端有、iOS 未接(iOS 待補 or 後端多餘)

_可能是後端先做 iOS 還沒接,或後端殘留廢端點。判斷寫進 findings.md。_

| # | 端點 | 後端來源 |
|---|---|---|
| 1 | `/base-products` | routes/base-products.js:8; routes/base-products.js:98 |
| 2 | `/base-products/:id` | routes/base-products.js:149; routes/base-products.js:217 |
| 3 | `/brands/:id` | routes/brands.js:145; routes/brands.js:33 |
| 4 | `/call/live-activity-token` | routes/call.js:940 |
| 5 | `/call/session/:id/accept` | routes/call.js:1095 |
| 6 | `/call/session/:id/decline` | routes/call.js:1128 |
| 7 | `/call/session/:id/preview` | routes/call.js:236 |
| 8 | `/call/teacher-live-activity-token` | routes/call.js:969 |
| 9 | `/call/teacher/offline` | routes/call.js:829 |
| 10 | `/call/teacher/online` | routes/call.js:812 |
| 11 | `/call/teacher/session/active` | routes/call.js:845 |
| 12 | `/call/teacher/student-products` | routes/call.js:999 |
| 13 | `/campaign/:id` | routes/campaign.js:309; routes/campaign.js:628 |
| 14 | `/campaign/:id/join` | routes/campaign.js:349 |
| 15 | `/campaign/upload-signature` | routes/campaign.js:236 |
| 16 | `/catalog` | routes/catalog.js:7 |
| 17 | `/catalog/:id` | routes/catalog.js:56 |
| 18 | `/challenges/check-in` | routes/challenges.js:26 |
| 19 | `/challenges/daily` | routes/challenges.js:38 |
| 20 | `/challenges/missions` | routes/challenges.js:52 |
| 21 | `/color/analyze` | routes/color.js:174 |
| 22 | `/color/compare` | routes/color.js:248 |
| 23 | `/color/convert` | routes/color.js:209 |
| 24 | `/detach/settings` | routes/detach.js:7 |
| 25 | `/detach/settings/:id` | routes/detach.js:18; routes/detach.js:30 |
| 26 | `/gift` | routes/gift.js:32 |
| 27 | `/gift/admin` | routes/gift.js:179; routes/gift.js:191 |
| 28 | `/gift/admin/:id` | routes/gift.js:269 |
| 29 | `/gift/admin/:id/deactivate` | routes/gift.js:301 |
| 30 | `/gift/admin/redemptions` | routes/gift.js:214 |
| 31 | `/gift/admin/redemptions/:id` | routes/gift.js:240 |
| 32 | `/gift/my-redemptions` | routes/gift.js:155 |
| 33 | `/gift/redeem` | routes/gift.js:58 |
| 34 | `/levels` | routes/levels.js:24 |
| 35 | `/makeup-product-types` | routes/makeup-product-types.js:9 |
| 36 | `/makeup-products/:id` | routes/makeup-products.js:439; routes/makeup-products.js:521 |
| 37 | `/makeup-products/:id/approve` | routes/makeup-products.js:379 |
| 38 | `/makeup-products/batch-match` | routes/makeup-products.js:417 |
| 39 | `/notifications/:id/events` | routes/notifications.js:487 |
| 40 | `/notifications/broadcast` | routes/notifications.js:552 |
| 41 | `/notifications/upload-signature` | routes/notifications.js:514 |
| 42 | `/posts/upload-signature` | routes/posts.js:74 |
| 43 | `/product-images` | routes/product-images.js:82 |
| 44 | `/product-images/:id` | routes/product-images.js:186 |
| 45 | `/product-images/:id/verify` | routes/product-images.js:111 |
| 46 | `/product-images/pending` | routes/product-images.js:63 |
| 47 | `/product-images/upload-signature` | routes/product-images.js:38 |
| 48 | `/products` | routes/products.js:142 |
| 49 | `/products/:id` | routes/products.js:178 |
| 50 | `/qa/upload-signature` | routes/qa.js:67 |
| 51 | `/report` | routes/report.js:7 |
| 52 | `/reviews/replies/:id` | routes/reviews.js:617 |
| 53 | `/templates` | routes/templates.js:65; routes/templates.js:7 |
| 54 | `/templates/:id` | routes/templates.js:130; routes/templates.js:49 |
| 55 | `/transactions/:id` | routes/transactions.js:85 |
| 56 | `/transactions/:id/status` | routes/transactions.js:216 |
| 57 | `/transactions/broadcast` | routes/transactions.js:184 |
| 58 | `/upload-new-makeup/product-types` | routes/upload-new-makeup.js:395 |
| 59 | `/upload-new-makeup/upload-signature` | routes/upload-new-makeup.js:370 |
| 60 | `/wishlist` | routes/wishlist.js:43 |
| 61 | `/wishlist/check-mapr/:id` | routes/wishlist.js:150 |
| 62 | `/withdrawals/:id/status` | routes/withdrawals.js:212 |
| 63 | `?/:id` | routes/join-campaigns.js:33; routes/scraper.js:126 |
| 64 | `?/analyze/:id` | routes/scraper.js:109 |
| 65 | `?/progress` | routes/scraper.js:80 |
| 66 | `?/run` | routes/scraper.js:13 |
| 67 | `?/run-all` | routes/scraper.js:41 |

## 🟡 只有 iOS 有、後端沒有(後端待補 or iOS 打錯/超前)

_可能是 iOS 先做後端還沒有(新規劃待決定),或 iOS 路徑寫錯。判斷寫進 findings.md。_

| # | 端點 | iOS 來源 |
|---|---|---|
| 1 | `/campaign-join/:id` | sevena/Services/CampaignAPIClient.swift:210 |
| 2 | `/reports` | sevena/Components/ReportSheet.swift:26 |

## 🟠 兩邊都有、但 method 不對稱

_(無)_

## 📜 契約 vs 兩邊實作

| 契約 | 端點 | 後端 | iOS |
|---|---|---|---|
| [call-session-cancel.md](../contracts/call-session-cancel.md) | `POST /call/session/:id/cancel` | ✅ | ✅ |

## ✅ 兩邊都有的端點(55 條,對齊基準線)

<details><summary>展開</summary>

- `/brands`
- `/call/pricing`
- `/call/request`
- `/call/session/:id/cancel`
- `/call/session/:id/end`
- `/call/session/:id/extend`
- `/call/session/:id/review`
- `/call/session/:id/status`
- `/call/topics`
- `/campaign`
- `/color-templates/hex-colors`
- `/color-templates/primary-colors`
- `/color/match`
- `/color/match-products`
- `/drafts`
- `/drafts/:id`
- `/drafts/:id/publish`
- `/gemini/analyze`
- `/invite/share-content`
- `/leaderboard`
- `/levels/award`
- `/levels/history`
- `/levels/me`
- `/makeup-products`
- `/makeup-products/approved`
- `/notifications`
- `/notifications/device-token`
- `/notifications/preferences`
- `/notifications/read`
- `/popular-colors`
- `/posts`
- `/posts/:id`
- `/posts/makeup-steps`
- `/posts/save-media`
- `/products/scan-match`
- `/profile`
- `/profile/check-name`
- `/profile/entity`
- `/profile/verify-invite`
- `/qa`
- `/qa/:id/replies`
- `/reviews`
- `/reviews/:id`
- `/reviews/:id/replies`
- `/shopping/search`
- `/transactions`
- `/upload-new-makeup`
- `/upload-new-makeup/:id`
- `/upload-new-makeup/color-search`
- `/users/:id/makeup-products`
- `/wishlist/add`
- `/wishlist/check/:id`
- `/wishlist/remove`
- `/withdrawals`
- `/withdrawals/upload-signature`

</details>

## ⚠️ 已知限制(啟發式萃取)

- 純 grep,非 AST:動態組出的路徑、`router.route().get()` 鏈式寫法、非 `apiClient.` 的呼叫可能漏抓。
- 路徑參數一律正規化成 `:id`,故 `/x/:a/:b` 與 `/x/:id/:id` 視為同一條。
- iOS method 取「呼叫後 200 字內最近的 `path:`」,跨太遠或多路徑同段可能誤配。
- routes/join-campaigns.js 有 1 條路由但 index.js 未見掛載,前綴記為 '?'
- routes/scraper.js 有 5 條路由但 index.js 未見掛載,前綴記為 '?'
