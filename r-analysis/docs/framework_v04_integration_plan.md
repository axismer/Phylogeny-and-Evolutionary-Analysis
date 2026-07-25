# Engineering Plan Report

> Framework **v0.4 Integration Phase** — 方案设计（第一阶段）  
> 日期：2026-07-25  
> 前置：Framework v0.3 P5（Fungi Plugin Validation）已完成  
> 状态：**仅设计，不修改代码**

---

## 约束（本阶段与后续实现均适用）

| 禁止 | 说明 |
|------|------|
| 不修改 `engine/` | 含 `phylogenetic_tree.R`、`ggtree_visualization.R` 等 |
| 不修改 virus / bacteria / fungi strategy | 生产策略冻结；集成只消费其契约 |
| 不改动 H3N2 benchmark | 基准脚本与产物保持可复现 |
| 本阶段不开始 Boot 改造 | 本文为 Engineering Plan；实现从 v0.4.1 起 |
| 目标不是新增 organism | archaea / eukaryote 仍可为 `not_implemented` |

**本阶段唯一交付物：** 本文件。

---

## 1. 当前架构状态

### 1.1 R Framework（已就绪，可被消费）

| 组件 | 路径 | 角色 |
|------|------|------|
| 统一 CLI | `runners/run_analysis.R` | `--type` / `--fasta` / `--metadata` / `--output` |
| Plugin registry | `strategies/strategy_registry.R` + 各 `strategies/*/plugin.R` | `register_strategy` / 扫描加载；生产类型：`virus`、`bacteria`、`fungi` |
| 编排 | `core/strategy_runner.R` | 统一 `run` 管线 |
| 结果写出 | `core/result_writer.R` | `analysis_result.json` v0.1 + P1 `error_code` |
| 错误码 | `core/error_codes.R` | 见 `docs/error_code_reference.md` |

生产 organism（v0.3 P5 后）：

| `--type` | 状态 |
|----------|------|
| `virus` | production |
| `bacteria` | production |
| `fungi` | production |
| `archaea` / `eukaryote` | `not_implemented`（exit 2） |

统一结果文件：`{--output}/analysis_result.json`（契约见 `docs/analysis_result_contract.md`）。

### 1.2 当前 Spring Boot（仍接旧入口）

| 项 | 现状 |
|----|------|
| 入口脚本 | `phylo.r.script=../r-analysis/engine/phylogenetic_tree.R` |
| 调用形态 | `Rscript <script> <fasta> <outputDir>`（位置参数，无 `--type` / metadata） |
| 实现类 | `ProcessBuilderRPhylogeneticAnalysisService` |
| API | `POST /api/r-analysis/run`（`RAnalysisController`） |
| 请求 DTO | `RAnalysisRequest(fastaPath, outputDir)` — 客户端自带绝对路径 |
| 结果 JSON DTO | `RAnalysisResultJson` — **legacy 字段**：`sequence_count` / `method` / `model` / `tree_file` / `matrix_file` / `image_file` / `status` |
| 响应 DTO | `RAnalysisResponse(status, treeFile, imageFile, sequenceCount, method, model)` |
| 成功判定 | `exitCode == 0` **且** `status == "success"`（不识别 `partial`；不读 `error_message` / `error_code` / `visualization`） |
| 并行 Java 流水线 | `POST /api/analysis/run` → `DistanceMatrixService` + `TreeService`（纯 Java UPGMA，与 R framework **无关**） |
| 数据根 | `phylo.data.root=../data`（`raw` / `matrix` / `tree`），**非** `r-analysis/input|output/tasks` |

### 1.3 当前文件流程（Boot → 旧 R）

```text
客户端提供绝对路径 fastaPath + outputDir
        ↓
POST /api/r-analysis/run
        ↓
ProcessBuilderRPhylogeneticAnalysisService
        ↓
Rscript engine/phylogenetic_tree.R <fasta> <outputDir>
        ↓
outputDir/
  distance_matrix.csv
  tree.nwk
  tree.png
  analysis_result.json   ← legacy 形态（无 organism_type / visualization / statistics 必填结构）
        ↓
Jackson → RAnalysisResultJson（只映射 legacy 键）
        ↓
RAnalysisResponse（路径 + 少量统计）
```

缺口（相对 v0.3 框架）：

1. 未调用 `runners/run_analysis.R`
2. 无 organism 选择、无 metadata 上传/传递
3. DTO 不覆盖冻结契约的必须字段
4. 无 `taskId` 隔离目录；输出目录由调用方任意指定
5. 前端主路径仍走 `/api/analysis/*`（Java 矩阵/树），未消费 R 多生物结果与 circular 图

### 1.4 当前前端

| 项 | 现状 |
|----|------|
| 主分析 UI | `App.vue`：`POST /api/analysis/run` → 矩阵 + Newick 矩形树 |
| R 闭环 API | 存在于 Boot，前端**未**作为主流程接入 |
| Organism 选择 | 无 |
| Metadata 上传 | 无（仅 FASTA 上传组件用于序列库路径） |
| Circular 可视化 | 无（R 产出 `circular_tree_final.png` 未被展示） |

---

## 2. 目标架构

### 2.1 端到端调用关系

```text
用户
  │
  ▼
Frontend
  │  选择 organism（virus | bacteria | fungi）
  │  上传 FASTA + metadata.csv
  │  触发分析 / 轮询或等待结果
  ▼
Spring Boot API
  │  校验参数、落盘、创建 taskId
  ▼
Task Service
  │  编排：输入目录 → 调用 R → 读结果 → 映射 DTO
  ▼
R runner
  │  Rscript runners/run_analysis.R
  │    --type <organism>
  │    --fasta <abs>
  │    --metadata <abs>   （策略要求时）
  │    --output <abs output/tasks/{taskId}>
  ▼
analysis_result.json  (+ tree.nwk, circular_tree_final.png, …)
  │
  ▼
Result DTO（Boot 解析契约字段 + 资源 URL/路径）
  │
  ▼
Frontend
     展示：tree（Newick）/ circular visualization / statistics / 错误信息
```

### 2.2 组件职责（目标态）

| 层 | 职责 |
|----|------|
| Frontend | organism 选择、文件上传、任务状态、结果分区展示 |
| API | 同步或异步任务端点；不直接拼 R 命令 |
| Task Service | 分配 `taskId`、写输入、调 R runner、读 JSON、映射错误码 |
| R runner（适配层） | ProcessBuilder → `run_analysis.R`；超时、stdout/stderr、exit 映射 |
| R Framework | 已冻结；按 `--type` 分发 strategy，写出契约 JSON |
| Result DTO | 以 v0.1 必须字段为准；legacy 别名仅 fallback |

### 2.3 与旧路径关系

| 路径 | v0.4 策略 |
|------|-----------|
| `engine/phylogenetic_tree.R` 直调 | **保留可配置回滚**一段时间；默认切到 `run_analysis.R` |
| `POST /api/analysis/*`（Java UPGMA） | 可并存为实验/演示；主产品路径切到 R multi-organism |
| H3N2 benchmark / `engine/` | **不改**；病毒生产路径继续由 VirusStrategy 内部委托 engine |

---

## 3. Spring Boot 改造范围

> 本节为范围清单；**本阶段不改代码**。

### 3.1 需要修改（高概率）

| 类别 | 文件 | 改造要点 |
|------|------|----------|
| **Config** | `backend/src/main/resources/application.properties` | `phylo.r.script` → `../r-analysis/runners/run_analysis.R`；新增 `phylo.r.root`、任务根目录、默认 timeout |
| **Config** | `backend/.../config/PhyloRProperties.java` | entrypoint、rscript、timeout、`rAnalysisRoot`（解析相对路径）、可选 `workingDirectory` |
| **Config** | `backend/.../config/PhyloDataProperties.java` 或新建 `PhyloTaskProperties` | `input/tasks`、`output/tasks` 根路径（建议锚定 `r-analysis/`） |
| **Service** | `.../service/r/RPhylogeneticAnalysisService.java` | 接口签名扩展：`type`、`metadata`、`taskId` / 路径 |
| **Service** | `.../service/r/ProcessBuilderRPhylogeneticAnalysisService.java` | 命令改为 named args；cwd 设为 `r-analysis` 根；exit 0/1/2 + status 映射；允许 `partial` |
| **DTO** | `.../dto/RAnalysisRequest.java` | 增加 `organismType`、`metadataPath` 或改为 multipart 任务模型 |
| **DTO** | `.../dto/RAnalysisResultJson.java` | 对齐契约：`organism_type`、`tree`、`visualization`、`metadata`、`statistics`、`error_message`、`error_code`；保留 legacy 别名 fallback |
| **DTO** | `.../dto/RAnalysisResponse.java` | 暴露 visualization、statistics、error_*、taskId、artifact URLs |
| **Controller** | `.../controller/RAnalysisController.java` | 新任务 API（见下）；错误响应带 `error_code` |
| **Task** | **新建** `.../service/task/AnalysisTaskService.java`（名称可调整） | 创建 taskId、落盘、调用 R、读结果、状态查询 |
| **Task** | **新建** DTO：`CreateAnalysisTaskRequest` / `AnalysisTaskResponse` | 上传或路径绑定后的对外模型 |

### 3.2 可选修改

| 类别 | 文件 | 说明 |
|------|------|------|
| Controller | `AnalysisController.java` | 标注 deprecated 或旁路保留；不必删除 |
| Config | `WebConfig.java` | 若需静态暴露 `output/tasks/{id}/*.png` 或受控下载端点 |
| DTO | `AnalysisRunResponse.java` | 仅当统一任务状态模型时复用/扩展 |

### 3.3 建议新增 API 面（设计）

```text
POST   /api/tasks                    # multipart: type + fasta + metadata → taskId
POST   /api/tasks/{taskId}/run       # 触发 R（或 create 时同步跑）
GET    /api/tasks/{taskId}           # 状态 + analysis_result 摘要
GET    /api/tasks/{taskId}/artifacts/{name}  # tree.nwk / png / csv（受控）
```

兼容过渡：可保留 `POST /api/r-analysis/run`，内部改为走 Task Service + `run_analysis.R`。

### 3.4 明确不改（v0.4 集成）

- `r-analysis/engine/**`
- `r-analysis/strategies/virus|bacteria|fungi/**`（除非发现契约消费 bug，另开议题）
- H3N2 benchmark 脚本与 `data/benchmarks/h3n2_ha` 产物
- 算法类 Java UPGMA 核心（除非产品决定下线 `/api/analysis`）

---

## 4. R 接口协议（冻结供 Boot 消费）

### 4.1 输入（CLI）

```bash
Rscript runners/run_analysis.R \
  --type <virus|bacteria|fungi|...> \
  --fasta <absolute-or-resolved-path.fasta> \
  --metadata <absolute-or-resolved-path.csv> \
  --output <absolute-or-resolved-path/output/tasks/{taskId}>
```

| 参数 | 必需 | 说明 |
|------|------|------|
| `--type` | 是 | 与 plugin registry / metadata.`organism_type` 一致 |
| `--fasta` | 是 | 序列文件 |
| `--output` | 是 | 任务输出目录（Boot 创建并传入） |
| `--metadata` | 策略依赖 | bacteria / fungi **要求**；virus 可选（影响 circular 可视化） |
| `--config` | 否 | 可选 `analysis_config.yaml` |
| `--rscript` | 否 | 嵌套调用 Rscript 时覆盖 |

**Process 工作目录：** 建议设为 `r-analysis/` 根，以便 strategy 相对路径与 registry 扫描稳定。

### 4.2 进程退出码

| Exit | `status` | Boot 处理建议 |
|------|----------|----------------|
| `0` | `success` / `partial` | 成功返回；`partial` 可带 warning |
| `1` | `error` | 业务失败；读 JSON 的 `error_code` / `error_message` → 4xx/422 或 200+error 体（产品二选一，推荐 **200 + status=error** 或 **422**） |
| `2` | `not_implemented` | 未知/未实现 organism → 400/501 |

超时：沿用 `phylo.r.timeout-seconds`；超时销毁进程，任务标记失败（可无 JSON，Boot 自写 error 摘要）。

### 4.3 输出：`analysis_result.json` 字段（消费契约）

必须字段（键不可缺）：

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | string | `success` \| `partial` \| `error` \| `not_implemented` |
| `organism_type` | string | 与 `--type` 一致 |
| `input` | string | FASTA 基名 |
| `tree` | string | 通常 `tree.nwk`；失败可为 `""` |
| `visualization` | string | 通常 `circular_tree_final.png`；无则为 `""` |
| `metadata` | string | 写出的 metadata 文件名；无则为 `""` |
| `statistics` | object | **禁止** JSON 数组；含 sequence_count / method / model / 扩展 |
| `error_message` | string | 非 error 时为 `""` |

失败态附加：

| 字段 | 条件 |
|------|------|
| `error_code` | `status=error` 或 `not_implemented` 时必须存在；success/partial **不得**出现该键 |

兼容别名（fallback，非必填）：`tree_file`、`sequence_count`、`method`、`model`、`matrix_file`、`image_file`。

权威文档：`docs/analysis_result_contract.md`、`docs/error_code_reference.md`。

### 4.4 Boot 解析优先级（设计）

```text
tree          ← tree；缺则 tree_file
visualization ← visualization；缺则 image_file（legacy）
statistics.*  ← statistics 内；缺则顶层 legacy 标量
errors        ← error_code + error_message（仅失败态）
```

---

## 5. 文件生命周期设计

### 5.1 目录布局

```text
r-analysis/
  input/tasks/{taskId}/
    sequences.fasta          # 或保留原始文件名
    metadata.csv             # 若有
  output/tasks/{taskId}/
    analysis_result.json     # 权威结果
    tree.nwk
    distance_matrix.csv
    circular_tree_final.png  # 主可视化（策略产出时）
    circular_tree_final.pdf
    tree.png                 # 矩形树（engine 中间产物，可选展示）
    metadata.csv             # strategy 写出副本（若有）
    run.log / run.err        # 可选：Boot 重定向
```

### 5.2 生命周期

| 阶段 | 动作 |
|------|------|
| **上传** | Task Service 生成 `taskId`（UUID），写入 `input/tasks/{taskId}/` |
| **运行** | 创建/清空或复用 `output/tasks/{taskId}/`；调用 R，`--output` 指向该目录 |
| **结果** | 以 `analysis_result.json` 为权威；产物文件名以 JSON 字段为准解析 |
| **异常** | R 失败仍应落盘 error JSON；若无 JSON（崩溃/超时），Boot 写最小 error 记录（任务状态表或旁路 `task_error.json`） |
| **清理** | 后续阶段：TTL / 磁盘配额（v0.4.3）；本设计预留策略，不强制首版实现 |

### 5.3 异常 JSON

优先复用 R 写出的 `analysis_result.json`（`status=error`）。  
Boot 兜底示例（仅当 R 未落盘时）：

```json
{
  "status": "error",
  "organism_type": "bacteria",
  "input": "sequences.fasta",
  "tree": "",
  "visualization": "",
  "metadata": "",
  "statistics": {},
  "error_message": "Rscript timeout or missing analysis_result.json",
  "error_code": "TREE_BUILD_FAILED"
}
```

（`error_code` 映射以产品规则为准；超时可单独码，若契约未列则暂用通用码并记日志。）

---

## 6. 并发问题

多用户同时分析时，隔离原则：**一切以 taskId 为边界**。

| 资源 | 隔离方式 |
|------|----------|
| 输入 | `input/tasks/{taskId}/` 互不覆盖 |
| 输出 | `output/tasks/{taskId}/` 互不覆盖 |
| R 进程 | 每任务独立 Process；禁止共享固定 `output/` 目录 |
| 临时文件 | R/strategy 内部临时文件必须落在 `--output` 或系统 temp + 唯一前缀；**禁止**写死 `output/tmp` 单目录 |
| 配置 | 共享只读 `analysis_config.yaml`；每任务覆盖项放入任务 ctx / 任务目录 |
| Boot 线程 | 同步 API 会占线程；并发升高后改为异步队列（v0.4.3）+ 有界线程池 |
| 全局状态 | R 进程级无共享；注意不要把 cwd 指到会互相写的相对路径 |

风险点（实现时验证）：

1. strategy 或 engine 是否写相对固定路径（集成测试双任务并行冒烟）
2. MAFFT / 外部工具工作目录是否冲突
3. Windows 路径长度与文件锁（输出 PNG 被前端占用时）

---

## 7. 前端交互设计

### 7.1 Organism selector

```text
[ virus ]  [ bacteria ]  [ fungi ]
```

- 默认值：产品决定（建议 `virus` 或上次选择）
- `archaea` / `eukaryote`：可灰显或隐藏（`not_implemented`）
- 切换 type 时提示对应 metadata 模板（`input/templates/{type}_metadata.csv`）

### 7.2 上传

| 控件 | 要求 |
|------|------|
| FASTA | 必需；`.fasta/.fa/.fas` |
| Metadata CSV | bacteria / fungi 必需；virus 可选但推荐（circular） |
| 校验 | 前端基础非空；权威校验在 R（`error_code` 回传） |

### 7.3 结果展示

| 区块 | 数据来源 |
|------|----------|
| **Tree** | `tree.nwk` → 现有 `PhylogeneticTreeView`（Newick）或后续增强 |
| **Circular visualization** | `visualization` → 图片 URL（`circular_tree_final.png`） |
| **Statistics** | `statistics` object（sequence_count、method、model、annotation_rings 等） |
| **错误** | `error_code` + `error_message` 可读展示；勿仅显示 HTTP 500 原文 |

### 7.4 交互流程（目标）

```text
选择 organism → 上传 fasta/metadata → 提交
  → loading（任务中）
  → success/partial：三区结果
  → error：错误面板 + 可重新上传
```

首版可采用同步等待（与现 `timeout-seconds` 对齐）；异步轮询列入 v0.4.3。

---

## 8. 风险分析

### 高

| 风险 | 影响 | 缓解 |
|------|------|------|
| Boot DTO/成功判定仍只认 legacy `success` + 顶层标量 | `partial` 被当失败；circular/statistics 丢失 | v0.4.1 先改解析契约与 exit 映射 |
| 无 taskId 隔离导致并发写同一目录 | 结果串扰、文件损坏 | 强制 `output/tasks/{taskId}` |
| Process cwd / 相对路径错误导致 registry/plugin 加载失败 | 全类型不可跑 | cwd=`r-analysis`；集成冒烟三类型各 1 次 |
| metadata 未传导致 bacteria/fungi 必败 | 前端体验差 | UI 按 type 强制 metadata；错误码直出 |

### 中

| 风险 | 影响 | 缓解 |
|------|------|------|
| 同步 API 长耗时占满 Tomcat 线程 | 多用户阻塞 | 有界并发 + 后续异步 |
| 静态文件直接暴露磁盘路径不安全 | 任意读风险 | 仅 artifact API + 路径规范化（禁 `..`） |
| Java UPGMA 与 R 双路径并存造成产品混淆 | 用户不知哪条是主路径 | UI 标明「多生物 R 分析」；旧入口降级 |
| Windows Rscript 绝对路径配置环境差异 | 部署失败 | `application.properties` 外置 + 健康检查端点 |

### 低

| 风险 | 影响 | 缓解 |
|------|------|------|
| legacy 别名字段残留 | DTO 略冗余 | 双读一段时间后删 fallback |
| archaea/eukaryote 误选 | exit 2 | UI 隐藏或明确「未实现」 |
| 历史 `analysis_result.json` 字段不全 | 仅影响旧目录 | 不回写历史；新任务一律新契约 |

---

## 9. 推荐实施顺序

### v0.4.1 — Boot ↔ R 协议接通（后端优先）

**目标：** Spring Boot 默认调用 `runners/run_analysis.R`，正确消费 `analysis_result.json`。

- 改 `PhyloRProperties` / `application.properties` entrypoint
- 改 ProcessBuilder 参数与 cwd
- 扩展 `RAnalysisResultJson` / `RAnalysisResponse`
- exit / status / `error_code` 映射
- 最小 Task 目录：`output/tasks/{taskId}`（可先手动或服务生成）
- 集成冒烟：`virus` / `bacteria` / `fungi` 各 1 条已知夹具
- **仍不改** engine、strategies、H3N2

**完成标准：** `POST` 带 type+fasta(+metadata) 可返回契约字段；失败返回 `error_code`。

### v0.4.2 — 任务生命周期 + 前端主路径

**目标：** 上传 → taskId → 运行 → 展示闭环。

- `AnalysisTaskService` + `input/tasks` / `output/tasks`
- 上传 API（multipart）
- Frontend：organism selector、metadata 上传、circular 图、statistics、错误面板
- 树视图继续复用 Newick 组件
- 文档：API 使用说明（可短文，非本阶段）

**完成标准：** 浏览器内完成三类型成功跑通与一类可复现错误展示。

### v0.4.3 — 并发、异步与硬化

**目标：** 多用户可用与运维友好。

- 异步任务 + 状态查询（可选 SSE/轮询）
- 有界并发、超时与清理策略
- Artifact 受控下载、路径安全
- 双任务并行冒烟；旧 `/api/r-analysis` 兼容层弃用计划
- （可选）健康检查：Rscript 可达 + registry 类型列表

**完成标准：** 并行任务无目录串扰；超时/失败可观测。

---

## 10. 本阶段结论

| 项 | 结论 |
|----|------|
| 集成切入点 | `run_analysis.R` + `analysis_result.json` 契约已足够作为 Boot 边界 |
| 最大缺口 | Boot 仍绑 legacy engine；DTO/前端未消费多生物结果 |
| 本阶段动作 | **仅产出本 Engineering Plan；不修改任何代码** |
| 下一动作 | 用户确认后进入 **v0.4.1**（Boot 协议接通） |

---

## 参考

- `docs/analysis_result_contract.md` — 结果 JSON 冻结契约  
- `docs/error_code_reference.md` — `error_code` 枚举  
- `docs/multi_organism_framework.md` — 框架总览与 Boot 切换阶段 B  
- `docs/framework_freeze_report.md` — v0.1 冻结与「Boot 旁路接入」建议  
- `docs/framework_v03_p5_report.md` — fungi production 完成基线  
- `docs/plugin_registry_design.md` — registry / plugin 加载  

---

**Engineering Plan Report — Framework v0.4 Integration Phase（设计完成，停止）**
