# 前後端對齊稽核 (alignment)

iOS (`sevena`) 與 backend (`sevena-backend`) 常「沒先口頭對齊就各做各的」——
可能後端先做、iOS 沒接;也可能 iOS 先做、後端還沒有。本資料夾追蹤這種不一致。

## 兩類產出(分工)

| 產出 | 誰產生 | 會被覆蓋? | 內容 |
|---|---|---|---|
| `<date>-endpoints.md` | `audit.py` 自動產生 | **會**(每次跑覆蓋) | 事實層:兩邊端點面 diff,只列事實不判斷 |
| `findings/<主題>.md` | **agent / 人**手寫 | 不會 | 判斷層:**一議題一篇獨立文章**(方向、待更新、待決定) |

> 事實層是拋棄式的快照;`findings/` 底下每篇才是要保留、要拿去跟兩邊對齊的結論。
> **不要**把多個議題塞進同一檔——分門別類,一個不一致一篇文章,並在 [`findings/README.md`](./findings/README.md) 索引維護狀態。

## 流程

1. **跑事實層**:`python3 .claude/skills/run-sevena-product/audit.py`
   → 產生/覆蓋 `alignment/<today>-endpoints.md`。
2. **做判斷**:對每條不一致,讀 iOS `sevena/openspec/`(主線規劃 + 前後文)、
   兩邊 git log、實際程式碼,判斷方向:
   - **iOS 打錯/路徑不符** → iOS 修正。
   - **後端先做、iOS 待接** → 開 iOS 工項。
   - **iOS 先做、後端還沒有** → 多半是「新規劃待決定」,需雙邊拍板正式契約。
   - **後端殘留廢端點** → 後端清理或補契約。
3. **寫 findings**:**每個不一致開一篇** `alignment/findings/<主題>.md`(格式見既有文章),並更新 `findings/README.md` 索引狀態。
4. **回填**:重大跨端決策 → `docs/adr/`;介面定案 → `contracts/`;進度 → `docs/PROGRESS.md`。

## 時機

用途是**等 iOS 主線開發告一段落後,拿來跟後端對齊**。iOS 開發中途路徑會頻繁進出,
不必每次 commit 都跑;主線功能收斂時跑一次,把落差一次清掉。

## 完整說明

見 skill:`.claude/skills/run-sevena-product/SKILL.md`。
