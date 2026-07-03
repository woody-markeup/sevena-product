# 檢舉功能路徑打錯:iOS `/reports` vs 後端 `/report`

- 首次發現:2026-07-01(`2026-07-01-endpoints.md` 事實層 🟡「只有 iOS」#2)
- 嚴重度:🔴 高 —— iOS 檢舉功能線上實際 404
- 影響範圍:iOS(後端無須動)
- 方向:**iOS 打錯路徑**(後端早已存在且正確)
- 狀態:待 iOS 修正

## 事實

- iOS `sevena/Components/ReportSheet.swift:26` `POST /reports`(複數),body 帶 `content_type` / `content_id` / `reason`。
- 後端只有 `index.js` `app.use('/report', ...)` + `routes/report.js:7` `router.post('/')` = **`POST /report`(單數)**。
- 事實層 diff:`/report` 落在「只有後端」#51、`/reports` 落在「只有 iOS」#2 —— 就是同一功能被單複數拆成兩條。

## 判斷

**iOS 打錯**。後端端點早已存在且正常,iOS 呼叫的是不存在的複數路徑 → 檢舉送出會 **404**,功能實際不通。

## 待更新

- iOS 把 `ReportSheet.swift:26` 的 `/reports` 改為 `/report`。
- 後端不動(以其現況為 single source of truth)。若堅持保留複數,後端加別名亦可,但不建議為了遷就打錯而增路徑。
