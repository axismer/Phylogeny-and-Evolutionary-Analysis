# Frontend Integration Guide（Framework v0.4.2-A）

> 面向前端开发人员的接口对接说明。  
> 范围：Spring Boot 任务 API（同步模式）。  
> 基准：v0.4.2-A 后端已完成；本阶段前端尚未接入。  
> 默认后端地址：`http://localhost:8080`

---

## 1. 当前系统架构

```text
Frontend
   ↓  HTTP (multipart / JSON)
Spring Boot API  (/api/tasks)
   ↓
AnalysisTaskService
   ↓  ProcessBuilder（后端内部，前端不可见）
R runners/run_analysis.R
   ↓
analysis_result.json
   ↓
AnalysisTaskResponse（返回前端）
```

说明：

- 前端**只**与 Spring Boot 通信。
- 任务输入/输出落在后端管控的 `r-analysis/input|output/tasks/{taskId}/`，前端不要直接读盘。
- R Framework 由 Boot 同步调用；一次 `POST` 会阻塞到分析结束（或失败）再返回。

---

## 2. 当前已完成能力

### 2.1 支持的 organism（`type`）

| type | 说明 | metadata |
|------|------|----------|
| `virus` | 已实现 | 可选（推荐上传） |
| `bacteria` | 已实现 | **必填**（缺失返回 `MISSING_METADATA_ARGUMENT`） |
| `fungi` | 已实现 | 可选（推荐上传） |

其他字符串（如 `archaea` / 未知值）会返回 `status: "not_implemented"`，`error_code: "UNSUPPORTED_ORGANISM"`。

### 2.2 已支持能力

- FASTA 上传（multipart 字段名：`fasta`）
- metadata CSV 上传（multipart 字段名：`metadata`，可选）
- `taskId`（UUID）生命周期：创建目录 → 落盘 → 跑 R → 持久化状态 → 可查询
- 调用 R：`runners/run_analysis.R`
- 解析 `analysis_result.json` 并封装进任务响应

### 2.3 尚不在本阶段

- 前端页面实现（本文档仅作对接规范）
- 异步队列 / 进度推送 / WebSocket / SSE
- 产物文件下载专用 API（见第 7 节限制）

---

## 3. API 接口说明

Base path：`/api/tasks`

### 3.1 创建并执行任务

**`POST /api/tasks`**

| 项 | 值 |
|----|----|
| Content-Type | `multipart/form-data` |
| 模式 | **同步**：上传后立即跑 R，响应体为最终结果 |
| 超时建议 | 前端请求超时建议 ≥ 10 分钟（后端默认 R 超时 600s） |

#### 表单参数

| 字段 | 必填 | 类型 | 说明 |
|------|------|------|------|
| `type` | 是 | string | organism：`virus` / `bacteria` / `fungi` |
| `fasta` | 是 | file | FASTA；扩展名建议 `.fasta` / `.fa` / `.fna` / `.fas` |
| `metadata` | 否* | file | CSV；`bacteria` 实际必填 |

\* API 层允许省略 `metadata`；R 侧对 `bacteria` 会报错。

#### 成功时的典型 HTTP

| 场景 | HTTP |
|------|------|
| `status` 为 `success` / `partial` | `200 OK` |
| `status` 为 `not_implemented` | `501 Not Implemented` |
| 上传校验失败（空 fasta、非法类型等） | `400 Bad Request` |
| 业务/R 失败（DNA 非法、缺 metadata 等） | `422 Unprocessable Entity` |
| 任务不存在（仅 GET） | `404 Not Found` |

> 前端应以响应体中的 `status` + `error_code` 为准，不要只依赖 HTTP 状态码。

#### 请求示例（curl）

```bash
curl -X POST "http://localhost:8080/api/tasks" \
  -F "type=virus" \
  -F "fasta=@./sequences.fasta;type=text/plain" \
  -F "metadata=@./metadata.csv;type=text/csv"
```

#### 请求示例（浏览器 `FormData`）

```javascript
const form = new FormData();
form.append("type", organismType);          // "virus" | "bacteria" | "fungi"
form.append("fasta", fastaFile);            // File
if (metadataFile) {
  form.append("metadata", metadataFile);    // File，可选
}

const res = await fetch("http://localhost:8080/api/tasks", {
  method: "POST",
  body: form, // 不要手动设 Content-Type，浏览器会带 boundary
});

const data = await res.json();
// data.taskId / data.status / data.result / data.error_code ...
```

#### 成功响应示例（同步结束后）

```json
{
  "taskId": "f9cac4a0-2cca-4ffd-b4fa-e65b9a8a8b99",
  "status": "success",
  "organism_type": "virus",
  "error_code": "",
  "error_message": "",
  "result": {
    "status": "success",
    "organism_type": "virus",
    "input": "sequences.fasta",
    "tree": "tree.nwk",
    "visualization": "circular_tree_final.png",
    "metadata": "metadata.csv",
    "statistics": {
      "sequence_count": 4,
      "method": "Maximum Likelihood",
      "model": "JC69"
    },
    "error_message": "",
    "error_code": "",
    "treeFile": "D:/Projects/phylo-platform/r-analysis/output/tasks/.../tree.nwk",
    "imageFile": "D:/Projects/phylo-platform/r-analysis/output/tasks/.../circular_tree_final.png",
    "sequenceCount": 4,
    "method": "Maximum Likelihood",
    "model": "JC69"
  }
}
```

#### 校验失败示例（缺 FASTA）

```json
{
  "taskId": "",
  "status": "error",
  "organism_type": "",
  "result": null,
  "error_code": "EMPTY_FASTA",
  "error_message": "fasta 文件不能为空"
}
```

---

### 3.2 查询任务

**`GET /api/tasks/{taskId}`**

| 项 | 值 |
|----|----|
| Path | `taskId` 必须为 UUID |
| 作用 | 读取已持久化的任务状态（`task_state.json`，必要时回退读 `analysis_result.json`） |

同步模式下，`POST` 已返回最终结果；`GET` 用于刷新/回看同一任务。

#### 返回字段（任务层）

| JSON 字段 | 含义 |
|-----------|------|
| `taskId` | 任务 UUID |
| `status` | 任务状态：`success` / `partial` / `error` / `not_implemented` /（中间态）`CREATED` |
| `organism_type` | 生物类型 |
| `result` | R 分析结果对象（见第 4 节）；失败时可能为 `null` |
| `error_code` | 错误码；成功通常为空串 |
| `error_message` | 错误说明；成功通常为空串 |

#### 请求示例

```bash
curl "http://localhost:8080/api/tasks/f9cac4a0-2cca-4ffd-b4fa-e65b9a8a8b99"
```

---

## 4. 返回数据结构

### 4.1 AnalysisTaskResponse（API 响应）

概念字段与 **实际 JSON 键名** 对照：

| 概念名 | JSON 键名 | 类型 | 说明 |
|--------|-----------|------|------|
| taskId | `taskId` | string | UUID |
| status | `status` | string | 见上表 |
| organismType | `organism_type` | string | `virus` / `bacteria` / `fungi` … |
| analysisResult | `result` | object \| null | 嵌套 R 结果（`RAnalysisResponse`） |
| errorCode | `error_code` | string | 任务级错误码 |
| errorMessage | `error_message` | string | 任务级错误信息 |

> 注意：嵌套分析结果字段名是 **`result`**，不是 `analysisResult`。

### 4.2 `result`（对应 analysis_result.json / RAnalysisResponse）

| JSON 键名 | 类型 | 说明 |
|-----------|------|------|
| `status` | string | `success` / `partial` / `error` / `not_implemented` |
| `organism_type` | string | 生物类型 |
| `input` | string | 输入 FASTA 名（常为 `sequences.fasta`） |
| `tree` | string | Newick 相对文件名，通常 `tree.nwk` |
| `visualization` | string | 图文件名，通常 `circular_tree_final.png` |
| `metadata` | string | metadata 文件名或空串 |
| `statistics` | object | 统计信息对象 |
| `error_code` | string | R/业务错误码 |
| `error_message` | string | R/业务错误信息 |

#### `statistics` 常用键

| 键 | 说明 |
|----|------|
| `sequence_count` | 序列数 |
| `method` | 建树方法（如 Maximum Likelihood） |
| `model` | 模型（如 JC69） |

Boot 还会在 `result` 顶层提供便于前端读取的别名：

| 键 | 说明 |
|----|------|
| `sequenceCount` | 同 `statistics.sequence_count` |
| `method` / `model` | 同 statistics |
| `treeFile` / `imageFile` | 服务器绝对路径（**仅调试**；生产前端勿当可访问 URL） |

### 4.3 前端推荐取值路径

```text
状态：          data.status
错误码：        data.error_code || data.result?.error_code
错误信息：      data.error_message || data.result?.error_message
树文件名：      data.result?.tree                 // "tree.nwk"
图文件名：      data.result?.visualization        // "circular_tree_final.png"
序列数：        data.result?.sequenceCount
                ?? data.result?.statistics?.sequence_count
方法：          data.result?.method
                ?? data.result?.statistics?.method
模型：          data.result?.model
                ?? data.result?.statistics?.model
```

---

## 5. 前端页面需要实现

### 页面 1：分析提交页

需要控件：

1. **Organism 选择**：`virus` / `bacteria` / `fungi`
2. **FASTA 上传**（必填）
3. **metadata 上传**（`bacteria` 必填；其他可选但建议提示）
4. **提交按钮** → `POST /api/tasks`

交互建议：

- 提交后显示 loading / “分析进行中…”，本阶段无进度百分比。
- 收到响应后：
  - `success` / `partial` → 跳转或切换到结果页，保存 `taskId`
  - `error` / `not_implemented` → 展示 `error_code` + `error_message`

### 页面 2：结果展示页

展示：

| 内容 | 数据来源 |
|------|----------|
| 分析状态 | `status` |
| tree（Newick） | `result.tree`（文件名）；树文本内容需后续产物 API 或临时方案 |
| circular 图 | `result.visualization`（常为 `circular_tree_final.png`） |
| sequence_count | `result.sequenceCount` / `statistics.sequence_count` |
| method | `result.method` / `statistics.method` |
| model | `result.model` / `statistics.model` |
| 错误信息 | `error_code` + `error_message` |

可用 `GET /api/tasks/{taskId}` 在结果页刷新。

> **当前缺口**：v0.4.2-A **尚未**提供 `GET /api/tasks/{taskId}/artifacts/{name}` 一类静态文件下载接口。  
> 前端暂时不要假设能用 `imageFile` 绝对路径直接 `<img src>`。展示 PNG/Newick 需等产物下载 API，或由后端后续补齐静态映射。

---

## 6. 错误处理

统一错误体形状：

```json
{
  "taskId": "...",
  "status": "error",
  "organism_type": "...",
  "result": null,
  "error_code": "EMPTY_FASTA",
  "error_message": "..."
}
```

（`not_implemented` 时 `status` 为 `"not_implemented"`，HTTP 常为 501。）

### 前端必须处理的错误码

| error_code | 典型场景 | 前端建议文案方向 |
|------------|----------|------------------|
| `EMPTY_FASTA` | 未选/空 FASTA | 请上传有效 FASTA 文件 |
| `INVALID_DNA` | 序列含非法碱基等 | 检查序列字母表/格式 |
| `MISSING_METADATA_ARGUMENT` | bacteria 未传 metadata | bacteria 必须上传 metadata.csv |
| `UNSUPPORTED_ORGANISM` | 未知 / 未实现 type | 仅支持 virus / bacteria / fungi |

### 其他可能出现的码（建议兜底展示）

| error_code | 说明 |
|------------|------|
| `INVALID_REQUEST` | type 为空、multipart 异常、文件过大等 |
| `INVALID_FILE_TYPE` | 扩展名/类型不符合预期 |
| `PATH_SECURITY_VIOLATION` | 非法文件名（含 `..` 等） |
| `TASK_NOT_FOUND` | GET 时 taskId 不存在 |
| `BOOT_RESULT_MISSING` | 结果 JSON 缺失或不可读 |
| `BOOT_PROCESS_FAILED` / `TREE_BUILD_FAILED` / `BOOT_TIMEOUT` | R/进程层失败 |

展示原则：始终同时显示 **`error_code` + `error_message`**；未知码用通用失败提示 + 原始 message。

---

## 7. 当前限制

- **同步执行**：`POST /api/tasks` 会阻塞至 R 完成。
- **无实时进度**：没有 percent / stage 推送。
- **无 WebSocket / SSE**。
- **大任务可能长时间等待**（病毒/细菌大数据集可达数分钟）；请提高前端超时并给出明确等待 UI。
- **无产物下载 API**：PNG / Newick 文件名已在 JSON 中，但浏览器尚不能直接通过 HTTP 取文件。
- **无任务清理 API**：历史 `taskId` 目录由后端落盘保留。

异步与进度计划在 **v0.4.3**。

---

## 8. 前端开发注意事项

1. **不要直接访问 `r-analysis/` 目录**（不要用 file://、不要拼服务器本地绝对路径）。
2. **所有请求必须经过 Spring Boot API**（`/api/tasks`）。
3. multipart 字段名必须是：`type` / `fasta` / `metadata`（不是 `organismType` / `file`）。
4. JSON 字段以 **snake_case 契约键** 为准：`organism_type`、`error_code`、`error_message`；嵌套结果在 **`result`**。
5. CORS：若前后端分端口开发，需确认后端 CORS 配置；同域反向代理可避免预检问题。
6. 上传大小：后端默认约 `50MB` / 请求 `55MB`；超限会得到结构化错误而非裸 500。
7. 成功判定：`status === "success" || status === "partial"`；不要仅用 `res.ok`。
8. `bacteria` 提交前在 UI 侧强制要求 metadata，减少无效长等待。

---

## 附录 A：最小对接流程

```text
1. 用户选择 type，选择 fasta（+ metadata）
2. POST /api/tasks  （等待）
3. 若 success/partial：
     保存 taskId
     展示 result 中的 statistics / tree / visualization 元数据
4. 若 error/not_implemented：
     展示 error_code + error_message
5. 可选：GET /api/tasks/{taskId} 回看同一任务
```

## 附录 B：与旧接口的关系

| 接口 | 状态 | 前端建议 |
|------|------|----------|
| `POST /api/tasks` | **主路径（v0.4.2-A）** | 新前端使用此接口 |
| `GET /api/tasks/{taskId}` | 查询 | 结果页刷新 |
| `POST /api/r-analysis/run` | 低层调试（绝对路径 JSON） | **前端不要使用** |

---

*文档版本：v0.4.2-A · 仅描述已落地后端能力，不包含未实现的前端或异步特性。*
