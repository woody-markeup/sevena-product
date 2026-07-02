# API 契約 (Contracts)

雙邊共用的 API 介面定義之 **single source of truth**。任何動到雙邊介面的變更,先改這裡、雙邊對齊後再各自實作。

## 建議內容

- API endpoint 規格 (OpenAPI / 手寫 schema)
- request / response DTO 定義
- 共用列舉、錯誤碼表
- 版本相容性說明

## 現有契約

- [call-session-cancel.md](./call-session-cancel.md) —— `POST /call/session/:id/cancel` 取消通話+退款。✅ 後端已實作,iOS 待接線(學生端缺口 #2)。

## 變更流程

1. 在此提出契約變更 (PR)
2. 開對應的 `docs/adr/` 決策記錄(若屬重大變更)
3. iOS 與 backend 各自依契約實作
4. 於 `docs/PROGRESS.md` 追蹤雙邊實作進度
