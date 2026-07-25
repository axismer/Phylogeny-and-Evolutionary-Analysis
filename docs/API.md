# REST API 设计（MVP 第一版）

Base URL：`http://localhost:8080`  
前缀：`/api`

跨域：开发阶段允许 `http://localhost:5173`（Vite 默认端口）。

---

## 1. 序列（FASTA）

### `GET /api/sequences/raw`

列出 `data/raw` 下已有 FASTA 文件名（供测试勾选）。

**响应示例**

```json
{
  "files": ["E.coli16S.fasta", "Bacillus subtilis16S.fasta"]
}
```

### `POST /api/sequences/upload`

上传一个或多个 FASTA，保存到 `data/raw/`。

- Content-Type：`multipart/form-data`
- 字段：`files`（多个文件）

**响应示例**

```json
{
  "saved": ["upload_xxx.fasta"]
}
```

### `GET /api/sequences/parse`

解析指定 raw 文件（或默认全部），返回物种标签与序列长度（不返回完整序列，避免响应过大）。

Query：

| 参数 | 说明 |
|------|------|
| `files` | 可选，逗号分隔文件名；省略则解析 raw 目录下全部 `.fasta`/`.fa` |

**响应示例**

```json
{
  "records": [
    {
      "sourceFile": "E.coli16S.fasta",
      "index": 0,
      "speciesName": "E.coli",
      "header": "NR_114042.1 Escherichia coli strain ...",
      "length": 1421
    }
  ]
}
```

---

## 2. 分析流水线（后续步骤实现）

### `POST /api/analysis/run`

触发完整流程：MSA → p-distance → UPGMA。

**请求体**

```json
{
  "inputFiles": ["E.coli16S.fasta", "Bacillus subtilis16S.fasta"]
}
```

若 `inputFiles` 为空，使用 `data/raw` 下全部 FASTA。

**响应示例**

```json
{
  "jobId": "local-20260721-001",
  "status": "COMPLETED",
  "alignedFile": "aligned/combined.aln",
  "matrixFile": "matrix/distance_matrix.csv",
  "treeFile": "tree/tree.nwk",
  "newick": "(A:0.1,(B:0.2,C:0.3):0.05);"
}
```

MVP 可同步执行，无需任务队列。

### `GET /api/analysis/matrix`

返回最新 `distance_matrix.csv` 文本或 JSON 二维表。

### `GET /api/analysis/tree`

返回最新 Newick 字符串。

---

## 3. 健康检查

### `GET /api/health`

```json
{ "status": "UP", "dataRoot": "D:/Projects/phylo-platform/data" }
```

---

## 错误约定

HTTP 4xx/5xx 时统一：

```json
{
  "error": "简短说明",
  "detail": "可选详细信息"
}
```
