# sync-repo

Consumer of the centrally maintained `config-sync` CI/CD component.

## Merge request checks and upload after merge

一般 consumer pipeline 可以在 MR 執行 lint、測試或 schema validation，只有
MR 合併到 default branch 後產生的 push pipeline 才執行 MinIO 上傳。完整範例：

```text
examples/merge-only.gitlab-ci.yml
```

範例的執行結果：

| Pipeline event | `validate-config` | `config-sync` |
|---|---:|---:|
| Merge request | Run | Skip |
| Push to default branch after merge | Skip | Run |
| Push to another branch | No pipeline | No pipeline |

Component 提供的 job 名稱是 `config-sync`。Consumer 可以再次定義同名 job，
只覆寫 `rules`；其餘 clone、tar、batch 與 MinIO upload 邏輯仍由 component
提供，不需要複製到 consumer。

GitLab 的 push pipeline 本身無法可靠區分「MR merge 造成的 push」和「直接
push 到 default branch」。若要求只有 MR 合併才能上傳，請同時在
**Settings > Repository > Protected branches** 保護 default branch，禁止直接
push，並要求 MR checks 成功後才能合併。

現有 `.gitlab-ci.yml` 是 webhook trigger demo，因此刻意保持不變。要採用
merge-only 流程時，把範例內容複製為 consumer repository 的
`.gitlab-ci.yml`。發布新版 component tag 後，也應把範例中的 `@1.0.0` 更新
為該版本，避免修改既有 immutable tag。
