# 跨端決策記錄 (ADR)

記錄影響 **iOS 與 backend 雙邊** 的整合決策。單一邊內部的技術決策請留在各自 repo。

## 命名

`NNNN-簡短標題.md`,例如 `0001-auth-token-refresh-策略.md`。

## 範本

```markdown
# NNNN. 標題

- 狀態: 提案中 | 已採用 | 已棄用 | 被 NNNN 取代
- 日期: YYYY-MM-DD
- 影響範圍: iOS / Backend / 兩者

## 背景
要解決什麼問題?為何需要雙邊一起決策?

## 決策
我們決定怎麼做。

## 影響
- iOS:
- Backend:
- 契約變更: (是否動到 contracts/)
```
