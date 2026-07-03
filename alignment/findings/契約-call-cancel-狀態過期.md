# 契約 `call-session-cancel` iOS 狀態標記過期

- 首次發現:2026-07-01(`2026-07-01-endpoints.md` 事實層「契約 vs 兩邊實作」表)
- 嚴重度:🟢 低 —— 文件落後,程式碼本身正確
- 影響範圍:文件(`contracts/`)
- 方向:**iOS 已追上,文件落後於程式碼**
- 狀態:待更新契約狀態欄

## 事實

- 契約 `contracts/call-session-cancel.md`(2026-06-30)寫「iOS 學生端 🟡 尚未接線(缺口 #2)」。
- 但 iOS 已接線:`sevena/Repositories/CallRepositoryImpl.swift:64` `POST /call/session/:id/cancel`,並有 `Domain/Call/CancelReason.swift`、`Infrastructure/CallLifecycleNotifier.swift:73`、`sevenaTests/CallLifecycleTests`。
- 事實層契約對照表:後端 ✅ / iOS ✅(兩邊皆有)。

## 判斷

iOS 已完成接線,**文件狀態標記過期**,不是實作缺口。

## 待更新

- 把契約內「iOS 缺口 #2 未接線」更新為「已接線」,補上 iOS 對應檔案位置。
- `reason` body 擴充維持 🟡(後端目前仍忽略 body,行為差異尚未實作)。
