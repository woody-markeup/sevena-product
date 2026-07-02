# 1v1 教學串流 — iOS 端 (sevena 學生 app)

> 回推自 `sevena/` codebase。本檔只記 **iOS 學生端**;後端訊令見 [backend.md](./backend.md)。
> 老師端為獨立 app `sevena-teacher`(sibling repo,不在本 product),本檔不涵蓋。

## 一句話

學生端用 **Agora RTC SDK** 加入後端指定的頻道(`session_<id>`)完成 1v1 視訊;發起後以 **2 秒輪詢** 等待配對成功,再 join 頻道。

## 連線技術

- **SDK:** Agora RTC(`import AgoraRtcKit`),非裸 WebRTC。媒體經 Agora 雲端中繼,非真 P2P。
- **頻道角色:** `clientRoleType = .broadcaster`(雙方皆廣播者 → 雙向視訊)。
- **鑑權:** `joinChannel(byToken: token, ...)`,token 來自後端 `status.token` —— **目前後端固定回 `null`**,等同 App ID-only(testing)模式。`appId` 取自 `AppConfig.agoraAppId`。

## 關鍵檔案(ARCH-012 基礎設施層,兩層深模組)

| 檔案 | 職責 |
|---|---|
| `sevena/Infrastructure/AgoraEngineWrapper.swift` | 封裝 `AgoraRtcEngineKit`,SDK 型別鎖死類內。對外 `setup/joinChannel/leaveChannel` + 視訊綁定 + `muteAudio/muteVideo/switchCamera`;媒體事件以 `AsyncStream<CallEvent>` 發出(`remoteUserJoined`/`localUserJoined`/`remoteUserLeft`)。`@MainActor`,`nonisolated init()`(engine 延後至 `setup(appId:)` 建立,避免 ServiceActor 非主執行緒解析時碰 MainActor)。 |
| `sevena/Infrastructure/CallCoordinator.swift` | 組合層:`callRepository`(配對)+ `agoraEngineWrapper`(SDK)。`beginSession()` 跑 request→輪詢→join 流程;`events` 合併媒體事件 + 配對事件(`matchFound`/`matchDeclined`/`matchFailed`)。`@ServiceActor`。 |
| `sevena/Domain/Protocols/CallCoordinatorProtocol.swift` | 深層協議。 |
| `sevena/Models/CallModels.swift` | `CallSession` / `CallEvent` / `teacherInfo` 等。 |
| `sevena/AppState/CallStore.swift` | 通話 UI 狀態。 |
| `sevena/Screens/Call/` | `CallRequestFlowView`、`CallWaitingScreen`、`CallScreen`、`CallReviewScreen`、`CallTopUpSheet`、`AgoraTestView`。 |

## 連線流程(`CallCoordinator.beginSession`)

```
repository.requestCall(topicId, styleId, duration)   // → POST /call/request
  ↓ 取得 sessionId + channelName(= session_<id>)
while !cancelled:                                     // 每 2 秒輪詢
    repository.fetchSessionStatus(sessionId)          // → GET /call/session/:id/status
    ├─ "matched"  → yield .matchFound
    │               wrapper.setup(appId: AppConfig.agoraAppId)
    │               wrapper.joinChannel(channelName, token: status.token(=nil), uid: status.uid ?? 0)
    │               return session
    ├─ "declined" → yield .matchDeclined → return nil
    └─ 其他       → sleep 2s 繼續輪詢
endSession() → wrapper.leaveChannel()
```

- **學生 uid:** `status.uid`(後端回的 `entiId`,即學生 entity id)。
- **沒有 WebSocket:** 學生端純輪詢得知配對結果。
- **連線中斷偵測:** legacy 未接,`.connectionLost` 暫無發送來源(`AgoraEngineWrapper` 註解標註待補)。

## 1v1 畫面清單(`sevena/Screens/Call/`)

全部為**學生端**畫面,無老師接單 UI:

| 畫面 | 行數 | 用途 |
|---|---|---|
| `CallRequestFlowView` | 439 | 發起請求:選「想學什麼」topic、彩妝步驟、時長、備註 → 找老師 |
| `CallWaitingScreen` | 302 | 等待配對(學生等老師) |
| `CallScreen` | 681 | 通話中視訊 |
| `CallReviewScreen` | 153 | 通話後評分(評 `teacherInfo` 對方老師) |
| `CallTopUpSheet` | 68 | 寶石加值(學生付費方) |
| `AgoraTestView` | 110 | QA 測試 |

## iOS 端有分老師/學生嗎?

**沒有 —— `sevena/` 的 1v1 畫面寫死是「學生視角」,只有學生那一半。**

- `MainTabView` 四個分頁:HomeFeed / MakeupBox / Leaderboard / Profile,無老師模式。
- `UserContext` / `UserContextStore` 無 role / isTeacher 欄位。
- **視訊標籤是角色寫死,不是依身分切換**(`CallScreen.swift`):
  ```swift
  L40   @State private var isLocalOnMain = false  // false = teacher big / student small
  L212  Text(isLocalOnMain ? "You" : "Teacher")   // 主畫面磚
  L254  Text(isLocalOnMain ? "Teacher" : "You")   // 子畫面磚(PiP)
  ```
  `isLocalOnMain` 只控制哪塊放大(L341 `toggle()` 切大小窗),**不判斷「我是不是老師」**。不管怎麼切,本地磚永遠 "You"、遠端磚永遠 "Teacher" → app 永遠假設「我=學生、對方=老師」,無 `if isTeacher` 分支。
- 程式碼中的 "teacher" 一律指**遠端對方**(`CallSession.teacherInfo`),非本機可切換角色。
- 老師看到的對應畫面(接單、對方標 "Student")在獨立 app `sevena-teacher`。角色區分發生在後端(`mua_account`)與該 app,**不在學生 app 的 UI**。角色模型詳見後端記錄。

## 待辦 / 風險

- ⚠️ **無 Token 鑑權**:`token` 全程 `nil`。上線前需接 Agora Token Server(屬契約層待規範項)。
- 連線中斷事件(`.connectionLost`)未接線。
