# sevena-product

Sevena 產品的**整合橋接層 (integration bridge)**。本 repo 不編譯、不執行任一邊的程式碼,職責是:

- 統整 iOS app 與 backend 雙邊的**整合規格與 API 契約**
- 追蹤雙邊**進度**與跨端**決策記錄**
- 作為雙邊溝通的 single source of truth

## 結構

```
sevena-product/
├── docs/          整合規格、進度看板、跨端決策記錄 (ADR)
├── contracts/     雙邊共用的 API schema / DTO 定義 (single source of truth)
├── scripts/       跨 repo 進度查詢腳本
├── sevena/        iOS app —— 獨立 clone,獨立 git 歷史 (本 repo gitignore)
└── sevena-backend/  Node 後端 —— 獨立 clone,獨立 git 歷史 (本 repo gitignore)
```

## 子專案

| 子專案 | 角色 | Remote |
|---|---|---|
| `sevena/` | iOS app | `git@fic.github.com:glorymakeup-com/sevena.git` |
| `sevena-backend/` | Node 後端 | `git@fic.github.com:glorymakeup-com/sevena-backend.git` |

兩個子專案各自 push 各自的 remote,git 歷史與本 repo 完全解耦。
初次取得專案時,在本目錄下分別 clone 上述兩個 repo 即可。

## 查看雙邊進度

```bash
./scripts/status.sh
```

匯總兩個子專案的目前分支、未提交變更、近期 commit。
