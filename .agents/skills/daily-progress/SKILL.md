---
name: daily-progress
description: 隨時檢查今天的進度。讀取今日的 To-do 記錄，查詢今天的 git commit 與工作區變動，自動對齊並產出三層結構的進度追蹤報告。
---

# Daily Progress Skill (檢查今日進度)

此技能用於一天的中途或任何時間，協助使用者隨時追蹤並檢查今日的開發進度。它會自動比對今日的 To-do 計畫與實際的 Git 異動，提供自動對齊的進度視覺化報告。

## 執行流程與指令

當此技能被觸發時，請依序執行以下步驟：

### 1. 取得基礎資訊
- **日期**：獲取當前日期，格式為 `YYYYMMDD` (例如 `20260702`)。
- **使用者名稱**：預設為 `Woody`（可從 git config 中的 user.name 取得，或直接使用 `Woody`）。

### 2. 載入今日的 To-do 記錄
- 讀取根目錄 `daily_sync/[YYYYMMDD]_todo.json` 或 `[YYYYMMDD]_todo.md`。
- 如果找不到，提示使用者先執行 `daily-start`。

### 3. 分析今日 Git 異動 (Git Activity)
- 查詢今日的所有 commit：`git log --since="midnight" --oneline`。
- 查詢工作區尚未 commit 的變動：`git status --porcelain`。
- 比對這些變動檔案與 commit message，自動與今日的 To-do 項目做關聯。

### 4. 生成並輸出三層結構的進度報告
將結果整理為以下三層結構。**注意：此輸出最後不要附上任何使用了哪些 Agent 技能或規定的備註。**

*   **第一層：目前進度概況** (給外人看的大綱，標示各項目的自動對齊進度，例如：`已有 Commit 提交`、`工作區修改中`、`尚無變動`)
*   **第二層：今日 Git 變更與提交明細** (列出今日實際的 commit 清單與目前工作區修改的檔案，提供核對來源)
*   **第三層：對齊時新加上項目的進度** (特別追蹤當初在對齊時新加上的任務進度)

```markdown
-----今日進度追蹤------
[使用者名稱] [YYYYMMDD] Progress
- 項目1 (狀態：已有 Commit 提交)
- 項目2 (狀態：工作區修改中)
- 項目3 (狀態：尚無變動)
- 新項目A (狀態：工作區修改中)

來源事項 (今日 Git 變更)：
- Commit 明細：
  * Commit ID - Commit Message
- 工作區未提交修改：
  * 檔案路徑

對齊時新加上：
- 新項目A：[狀態]
```

### 5. 保存記錄至回報資料夾
- 將上述三層結構的完整 Markdown 內容，保存至主專案回報資料夾：
  `daily_sync/[YYYYMMDD]_progress.md`。
