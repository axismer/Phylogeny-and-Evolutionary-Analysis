# 系统发育分析与进化树展示平台 — 项目复盘文档

> 文档性质：工程复盘（非产品宣传）  
> 复盘对象：当前仓库已落地的 MVP 实现  
> 编写约束：仅基于实际代码与目录；明确标注「未实现」项，避免把设计文档中的规划写成现状  
> 相关文档：`docs/PROJECT_STRUCTURE.md`、`docs/API.md`、根目录 `README.md`

---

# 1. 项目背景

## 1.1 项目目标

本项目目标是做一个**可本地运行**的系统发育分析演示平台：从一组 16S rRNA FASTA 序列出发，完成距离估计与有根树构建，再通过 REST API 与简单网页把结果展示出来。技术栈选择是常见的教学/课程设计组合——后端 Spring Boot，前端 Vue 3 + Vite，数据落在文件系统而非数据库。

更具体地说，项目要回答的工程问题不是「如何发表一篇系统发育学论文」，而是：

1. 如何把生物信息学流水线拆成可测试的 Java 模块；
2. 如何用清晰的分层（Controller / Service / Model）把算法接到 HTTP；
3. 如何用最少的前端页面把矩阵与 Newick 结果可视化到浏览器。

## 1.2 解决的问题

在没有引入 NCBI 在线检索、MSA 外部工具、任务队列与用户体系的前提下，项目解决了以下几类问题：

| 问题 | 当前解法 |
|------|----------|
| FASTA 文件如何结构化读入 | `FastaParser` + `FastaService` → `FastaRecord` |
| 多物种距离如何计算并持久化 | `PDistanceCalculator` + CSV 写到 `data/matrix/` |
| 距离矩阵如何变成树 | `UpgmaBuilder` + `NewickWriter` → `data/tree/tree.nwk` |
| 算法如何被前端调用 | `AnalysisController` 三个接口 |
| 结果如何给人看 | Vue 页：表格矩阵 + 简易树形分支 |

测试数据方面，仓库 `data/raw/` 中已有 **14 个** 16S FASTA 文件，作为端到端联调输入。

## 1.3 当前实现范围（以代码为准）

**已实现：**

- Backend：FASTA 读取与解析；p-distance 距离矩阵；CSV 读写；UPGMA 建树；Newick 输出；`AnalysisRunner` 本地流水线；`SequenceController`（health / list raw / parse）；`AnalysisController`（run / matrix / tree）；CORS 对 `localhost:5173`
- Frontend：Axios 调后端；「开始分析」按钮；距离矩阵 HTML table；Newick 简易解析与嵌套树展示
- 数据产物：`data/matrix/distance_matrix.csv`、`data/tree/tree.nwk`
- 单测：FASTA、p-distance、CSV reader、UPGMA、Newick、AnalysisController MockMvc 等

**明确未实现（虽设计文档曾提及）：**

- MSA / Clustal Omega / MUSCLE / MAFFT（`service/alignment` 包在结构说明中预留，**无实现类**）
- 文件上传接口 `POST /api/sequences/upload`（`docs/API.md` 有设计，**Controller 未落地**）
- 数据库、用户、任务队列、NCBI 模块
- Neighbor Joining / Maximum Likelihood / Bootstrap
- 专业树布局（D3 / iTOL 风格）、矩阵热力图
- Pinia、Vue Router、多页面路由

另外：根目录 `README.md` 进度表仍写着「MSA / 距离矩阵 / UPGMA 待做」「Vue 待做」，与当前代码**不同步**。复盘应以源码与已跑通流程为准，README 属于待更新文档债。

## 1.4 当前版本定位

**定位：MVP / Demo。**

理由：

1. 距离计算直接基于 raw 截断，代码注释已写明「该截断策略仅用于MVP版本测试，正式系统后续将接入MSA模块。」
2. 分析同步执行、单机文件覆盖写，适合课堂演示与联调，不适合多用户并发科研生产。
3. 前端只覆盖「一键分析 → 看结果」，交互与可视化深度刻意压低。

因此，本复盘默认读者理解：**能跑通 ≠ 生物学流程已正确到可发表。**

---

# 2. 项目整体架构

## 2.1 仓库目录（实际）

```text
phylo-platform/
├── backend/                 Spring Boot 3.4 + Gradle
├── frontend/                Vue 3 + Vite + Axios
├── data/
│   ├── raw/                 输入 FASTA（14 个测试文件）
│   ├── aligned/             预留目录（当前流水线未写入）
│   ├── matrix/              distance_matrix.csv
│   └── tree/                tree.nwk
└── docs/                    API、结构说明、本复盘文档
```

`application.properties` 中 `phylo.data.root=../data`，要求从 `backend/` 工作目录启动，才能正确解析到仓库级 `data/`。

## 2.2 Backend 结构

包根：`com.phylo.platform`

| 层 | 实际内容 |
|----|----------|
| 启动 | `PhyloPlatformApplication`；可选流水线入口 `AnalysisRunner`（`phylo.analysis.run-on-startup=true` 或 `gradle runAnalysis`） |
| config | `AppConfig`、`PhyloDataProperties`（raw/aligned/matrix/tree）、`WebConfig`（CORS） |
| controller | `SequenceController`（`/api/health`、`/api/sequences/*`）；`AnalysisController`（`/api/analysis/*`） |
| dto | `FastaRecordSummary`、`AnalysisRunResponse`、`DistanceMatrixResponse`、`TreeResponse` |
| model | `FastaRecord`、`DistanceMatrix`、`TreeNode`、`PhylogeneticTree` |
| service.fasta | `FastaParser`、`FastaService` |
| service.matrix | `PDistanceCalculator`、`DistanceMatrixService`、`DistanceMatrixCsvWriter`、`DistanceMatrixCsvReader` |
| service.tree | `UpgmaBuilder`、`NewickWriter`、`TreeService` |
| service.alignment | **不存在实现**（仅文档预留） |

分层原则在实践中基本守住了：**算法在 Service，HTTP 在 Controller，文件路径在 Properties**。`AnalysisController.run()` 只串联已有 `DistanceMatrixService.computeAndWriteFromRaw()` 与 `TreeService.buildAndWriteFromMatrixFile()`，没有把算法塞进 Controller。

## 2.3 Frontend 结构（实际）

```text
frontend/src/
├── main.js
├── App.vue                 页面编排：按钮 + 状态 + 两个结果区
├── styles.css
├── api/
│   ├── http.js             axios 实例，baseURL=http://localhost:8080
│   └── analysis.js         run / matrix / tree 封装
├── components/
│   ├── DistanceMatrixTable.vue
│   ├── PhylogeneticTreeView.vue
│   └── TreeBranch.vue      递归渲染树节点
└── utils/
    └── newick.js           简易 Newick 解析
```

未使用 Router / Pinia。API 调用方式：Axios 直连后端绝对地址，依赖后端 CORS；没有 Vite proxy 作为必需路径（虽可后续加）。

可视化：

- 矩阵：原生 HTML `<table>`，表头为 `labels`，单元格为 `values`
- 树：`parseNewick` → 递归 `TreeBranch`，用左边框嵌套表达拓扑，并显示枝长数字；另有 `<details>` 展示 Newick 原文

## 2.4 当前真实数据流

与早期结构文档中「MSA → aligned → p-distance」的理想路径不同，**当前线上路径是：**

```text
data/raw/*.fasta
    ↓
FastaService / FastaParser
    ↓
DistanceMatrixService
  （每文件取首条序列；按最短长度截断）
    ↓
PDistanceCalculator（p-distance）
    ↓
data/matrix/distance_matrix.csv
    ↓
TreeService ← DistanceMatrixCsvReader
    ↓
UpgmaBuilder → PhylogeneticTree
    ↓
NewickWriter → data/tree/tree.nwk
    ↓
REST API（AnalysisController）
    ↓
Vue（Axios）展示矩阵与树
```

本地不经过 HTTP 的验证入口是 `AnalysisRunner`：同样调用上述两个 Service，打印 FASTA 数量与产物路径。

---

# 3. 开发阶段记录

以下顺序对应本次 Cursor 辅助开发的实际推进轨迹，而非理想科研流水线顺序。

## 阶段1：项目初始化

完成内容：

- Spring Boot 工程（Gradle、Java 21、`spring-boot-starter-web`）
- `PhyloDataProperties` 统一 `data` 根路径与子目录
- 仓库级 `data/{raw,aligned,matrix,tree}` 与 `.gitkeep`
- `WebConfig` 预先放开 Vite 端口跨域
- `docs/PROJECT_STRUCTURE.md`、`docs/API.md` 作为契约草稿

这一阶段的价值在于：**先定目录与分层，再往里填算法**。后续每个 Service 都能自然落到对应包与对应数据目录，减少「临时路径字符串散落」的问题。

## 阶段2：FASTA 读取模块

主要类：

- `model.FastaRecord`：sourceFile、index、speciesName、header、sequence
- `service.fasta.FastaParser`：文本解析；文件名推断物种名（去掉 `16S` 后缀等）
- `service.fasta.FastaService`：列目录、按名解析、路径穿越校验
- `SequenceController`：`/api/sequences/raw`、`/api/sequences/parse`
- `FastaParserTest`

**为什么拆 Parser 与 Service：**

- Parser 无 Spring 状态，易单测、易复用（读文件 / 读 Reader）
- Service 负责「平台语义」：raw 目录、文件过滤、安全路径、批量编排
- 后续距离模块只需依赖 `List<FastaRecord>`，不必知道 FASTA 文本细节

这是后续「模块独立、禁止随意改已有 Service」约束能落地的基础。

## 阶段3：距离矩阵模块

主要类：

- `DistanceMatrix`：labels + values，要求方阵
- `PDistanceCalculator`：两序列 p-distance；跳过 N/非 ATCG；构建对称矩阵
- `DistanceMatrixCsvWriter` / `DistanceMatrixCsvReader`
- `DistanceMatrixService`：读 raw → 每文件首条 → **最短长度截断** → 计算 → 写 CSV
- `PDistanceCalculatorTest`、`DistanceMatrixCsvReaderTest`

算法公式：`不同碱基数 / 可比较位点数`。

关键产品决策（人工确认后才实现）：

1. 一文件一种 taxon，只取第一条序列；
2. 暂不做 MSA，用截断对齐共同前缀区；
3. 在注释中强制留下生物学限制说明。

该阶段还出现过一次「先设计类清单、再写代码」的节奏，避免 AI 一开始就把 Controller、上传、MSA 全堆进来。

## 阶段4：UPGMA 建树模块

主要类：

- `TreeNode`：label、left/right、height、size、branchLength（由 height 差设置）
- `PhylogeneticTree`：root + taxonLabels
- `UpgmaBuilder`：最近簇合并 + size 加权平均更新距离
- `NewickWriter`：根节点不输出枝长，形如 `((A:0.1,B:0.1):0.2,C:0.3);`
- `TreeService`：从默认 CSV 建树并写 `tree.nwk`
- `UpgmaBuilderTest`（含三物种手工矩阵）、`NewickWriterTest`

验证方式不仅是单测，还包括 `AnalysisRunner` 对 14 物种全流程写出文件，人工检查：

- 矩阵对角线为 0、行列与物种数一致；
- Newick 以 `;` 结尾、叶标签可对应物种名。

## 阶段5：REST API

在算法跑通之后才加 HTTP，中间曾明确「暂缓 REST、先 AnalysisRunner」，这避免了前后端同时调试时的责任混淆。

`AnalysisController` 最终接口：

| 方法 | 路径 | 行为 |
|------|------|------|
| POST | `/api/analysis/run` | 矩阵 → 树；返回 `{status, message}` |
| GET | `/api/analysis/matrix` | 读 CSV → `{labels, values}` |
| GET | `/api/analysis/tree` | 读 nwk → `{newick}` |

DTO 使用简单 Java record，与领域 model 分离：HTTP 形状变化不必改算法对象。

验证：`gradle test` + 真实 `bootRun` + `curl` 三接口 HTTP 200。

## 阶段6：Vue 展示

在后端稳定后才初始化 `frontend/`（此前仅有占位 README）。

实现要点：

- 「开始分析」串行/并行拉取：先 `run`，再 `Promise.all([matrix, tree])`
- 错误展示依赖后端 `{error, detail}` 或网络异常文案
- 树可视化刻意做成「结构可见」而非「专业排版」

此阶段约束「不改 backend」被严格执行，前后端耦合仅通过已冻结的三个分析接口。

---

# 4. AI辅助开发过程复盘（重点）

## 4.1 有效的方法

### （1）先设计、后实现，关键决策人工确认

距离矩阵、UPGMA、REST 都出现过「只输出设计方案，不要改代码」的回合。人工确认了截断策略、Newick 根节点是否带枝长、是否增加 `DistanceMatrixCsvReader` 等后再开工。

**为什么有效：** AI 一旦进入实现模式，容易顺手「补全」MSA、上传、任务 ID、异步队列等。设计门禁把扩展冲动挡在编码之前。

### （2）按模块纵向切片，而不是横向一次铺完

顺序是 FASTA → 矩阵 → 树 → Runner 验证 → API → Vue，而不是「同时写全栈」。

**为什么有效：** 每层都有可验证产物（解析结果、CSV、nwk、HTTP JSON、页面）。失败时定位范围小。

### （3）每完成模块立即测试 / 跑通

后端各模块有单元测试；矩阵与树有手工算例；全流程用 `AnalysisRunner` / `runAnalysis`；API 用 curl；前端用 `npm run dev` 确认页面可开。

**为什么有效：** 把「编译通过」和「业务链路通」拆开验证，减少最后集成爆炸。

### （4）明确禁止修改已完成模块

多次提示「不修改 FastaService / DistanceMatrixService / UpgmaBuilder / TreeService 核心逻辑」。新能力以新增类或仅调用既有 public 方法完成。

**为什么有效：** AI 重构冲动很强；冻结边界后，回归风险显著下降，也符合教学项目「阶段交付可复查」的需求。

### （5）用本地 Runner 把算法与 HTTP 解耦验证

在 REST 之前用 `AnalysisRunner` 证明 Service 编排正确。

**为什么有效：** 避免「接口 500 不知道是 Tomcat、路径还是算法」的混合排障。

## 4.2 使用的提示词模式

下列模式在本项目中反复出现，且显著降低失控风险：

| Prompt 模式 | 作用 |
|-------------|------|
| 「只设计，不改代码 / 等待确认」 | 强制产出可评审方案，阻止静默写盘 |
| 「保持现有结构，只新增模块」 | 限制改动面到新包/新类 |
| 「不要修改已有 Service / Parser」 | 保护已测核心 |
| 「实现后运行测试 / curl 验证」 | 把完成定义从「写了文件」变成「有证据」 |
| 「不要前端 / 不要数据库 / 不要 NCBI」 | 显式砍掉范围蔓延 |
| 「基于当前代码分析，不要凭空扩展」 | 复盘与设计都锚定仓库现状 |

这些提示词之所以有效，本质是给 AI **缩小动作空间**：不能改什么、做到哪算完、用什么证据证明。没有约束时，模型默认优化「看起来完整的系统」；有约束时，才优化「当前阶段的正确增量」。

反例也值得记录：早期若只说「把系统发育平台做完」，很容易一次生成 MSA 调用、上传、异步 job、花哨前端，与课程阶段目标和现有目录契约冲突。

## 4.3 AI容易出现的问题（结合本项目）

### （1）过早扩展功能

结构文档与 API 文档里写了 MSA、upload、jobId、完整 analysis 响应字段；AI 容易把文档当成「必须立刻实现」。本项目通过阶段门禁，把 upload / MSA / job 明确推后，但 **README 与代码脱节** 说明文档维护仍依赖人工。

### （2）过度设计

若放任，可能出现抽象工厂、策略模式全家桶、通用 Pipeline 框架。实际落地保持了「一步一个 Service + 文件产物」，对 MVP 更合适。UPGMA 内部用简单 Cluster 列表即可，没有引入图论库。

### （3）测试通过 ≠ 业务正确

三物种手工矩阵单测能证明 UPGMA 实现与公式一致；**不能**证明 14 条 raw 截断距离在微生物学上合理。p-distance 偏高、拓扑怪异时，AI 不会主动质疑数据预处理，只会报告 BUILD SUCCESSFUL。

### （4）无法自动判断生物学合理性

截断策略、是否忽略 N、UPGMA 分子钟假设、16S 拷贝数与物种命名——这些都需要人审。AI 可以按指示把警告写进注释，但**不会替代生信审查**。

### （5）运行环境细节踩坑

例如 Windows 下 Gradle Wrapper 缺失、`-D` 参数被 PowerShell 吞掉、`bootRun` 仍走默认主类、控制台中文乱码等。AI 可能给出「看起来正确」的命令，仍需结合本机环境修正（最终用 `runAnalysis` JavaExec 任务解决 AnalysisRunner 启动问题）。

### （6）把「设计态」写成「已完成」

若不强调「基于实际代码」，复盘或 README 会把 `aligned/`、MSA、upload 写成已完成。本复盘刻意把未实现项单列。

---

# 5. 技术问题总结

## 5.1 生物信息学方面

1. **raw 截断不是正式比对**  
   `DistanceMatrixService.truncateToMinLength` 取最短长度截前缀。不同测序/注释起点不一致时，共同前缀未必同源可比。正式流程应先 MSA，再在比对列上计距离。

2. **`data/aligned/` 空置**  
   目录已建，流水线未使用。说明架构预留正确，但当前科研正确性缺口仍在预处理。

3. **p-distance 模型限制**  
   未校正多重替换；高差异时距离饱和、低估真实分化。教学可用，推断深缘关系不可靠。

4. **UPGMA 依赖分子钟**  
   速率异质时拓扑与枝长易偏。细菌 16S 场景有时「看起来像树」，不代表方法最优。

5. **序列与物种语义简化**  
   一文件一物种、只取第一条记录；多拷贝 16S、污染、错误命名都未处理。

6. **N 与模糊碱基**  
   计算时跳过非 ATCG，可能导致有效位点偏少；极端情况下抛「无有效比较位置」。策略简单，但未做位点覆盖率报告。

## 5.2 算法方面

1. 仅实现 UPGMA，无 Neighbor Joining、无 ML/Bayes。
2. 无 Bootstrap / SH-aLRT 等支持度。
3. 无替代模型选择（JC、K2P、GTR 等）。
4. 平局合并依赖实现细节（id / size 规则）保证可复现，但不同实现细节可能导致并列距离时拓扑细节差异——应用测试锁定期望。
5. 距离矩阵与树均为单次覆盖写，无版本号，无法对比参数实验。

## 5.3 前端方面

1. 矩阵是数字表，不是 heatmap；14×14 尚可，规模上升可读性差。
2. 树是嵌套分支示意，非等距树/径向树；枝长只是文字，不按长度比例绘图。
3. Newick 解析器为自研简易版，覆盖本项目输出格式；对复杂注释、多叉、损坏字符串的健壮性有限。
4. 无加载进度细分（只有「分析中」），长任务体验一般。
5. 未对接 `GET /api/sequences/*`（列表/解析），前端不能选子集分析——也因后端 `POST /run` 固定全量 raw。

## 5.4 工程方面

1. **无数据库**：状态即磁盘文件；并发两次 `/run` 会互相覆盖。
2. **无任务管理**：分析同步阻塞 HTTP；物种增多或将来接 MSA 时会超时。
3. **无用户系统 / 权限**。
4. **文件上传未实现**：只能用仓库预置 raw 或手工拷贝文件。
5. **文档债**：`README.md` 进度、`PROJECT_STRUCTURE.md` 中 MSA 步骤与现状不符；`API.md` 部分字段（jobId、alignedFile、upload）超前于实现。
6. **配置耦合工作目录**：`phylo.data.root=../data` 在 IDE 运行配置错误时会写到错误位置，排障成本真实存在。
7. **测试缺口**：缺少针对 14 文件端到端的自动化集成测试（目前靠 Runner / 手工 curl）；Controller 测试以 Mock 为主。

---

# 6. 当前项目优点

客观来看，作为 MVP，项目有几处做得扎实：

1. **分层清晰**：fasta / matrix / tree 分包，Controller 薄，符合「一步一个 Service」的初始原则。
2. **算法模块独立可测**：p-distance、UPGMA、Newick、CSV 都有针对性单测；关键算例（ACGT/ACCT=0.25；三物种 UPGMA）可人工复核。
3. **前后端分离且契约短**：前端只依赖三个 analysis 接口即可闭环，降低联调复杂度。
4. **数据流完整可演示**：从 raw 文件到浏览器可见矩阵与树，路径闭环。
5. **文件系统 intermediate 产物可复查**：CSV 与 nwk 可用文本编辑器 / 第三方树查看器交叉验证，不依赖 UI。
6. **扩展点预留合理**：`aligned/` 目录、`PhyloDataProperties` 子路径、文档中的 alignment 包位置，后续接 MSA 时不必推翻分层。
7. **开发过程可回放**：设计确认 → 实现 → 测试 → Runner → API → Vue 的节奏，适合作为 AI 辅助工程的案例材料。
8. **范围控制有效**：在多次「不要数据库 / 不要 NCBI / 不要改已有 Service」约束下，仓库没有膨胀成半成品大杂烩。

这些优点的共同点是：**正确性边界被说清楚，完成定义可检查**。

---

# 7. 如果继续开发，下一阶段路线

以下仅为规划优先级，**不是本复盘的实现任务**。

## P0：保证科研流程正确（最高优先）

目标：让距离建立在可比对位点上。

- 引入外部 MSA（优先 MAFFT，或 MUSCLE / Clustal Omega），写入 `data/aligned/`
- `DistanceMatrixService` 改为读取比对后的等长序列（或显式 gap 处理规则）
- 去掉（或降级为 debug 开关）raw 截断策略
- 更新 README / API / 结构文档，消除「已完成」与「规划」混淆
- 增加比对质量基本检查：长度、gap 比例、有效位点数量报告

## P1：提升分析能力

- 增加 Neighbor Joining（对速率异质更常用）
- 可选：调用外部 IQ-TREE / RAxML-NG 做 ML（Java 包装进程）
- Bootstrap 或超快 bootstrap，把支持度写入 Newick 注释或并行结果文件
- 距离模型升级：JC69 / K2P 等，不仅是 p-distance
- `POST /run` 支持 `inputFiles` 子集（API 文档已有草案）

## P2：平台化

- 文件上传与 raw 管理（补齐 upload API + 前端选择器）
- 任务表 / 结果版本（哪怕先 SQLite）
- 异步任务队列 + jobId 查询（长耗时 MSA 必需）
- 用户与简单权限（若走向多用户）
- 配置与工作目录问题工程化（绝对路径、安装向导）

## P3：展示优化

- 矩阵 heatmap（颜色编码距离）
- D3 / phylotree / 类 iTOL 的可缩放树布局，枝长按比例
- 并排对比不同方法树、下载 CSV/NWK
- 更好的错误与进度 UX

建议执行策略：**先 P0，再考虑 P1 的一种建树法**；不要在截断距离未修正前优先做漂亮可视化（P3），否则会强化错误结果的可信外观。

---

# 8. 本次 Cursor 开发经验总结

## 8.1 哪些工作适合交给 AI

- 在既定接口与包结构下，生成样板代码（DTO、Controller 映射、CSV 读写）
- 按明确公式实现小算法（p-distance 位点循环、Newick 递归写出）
- 补单元测试骨架与典型断言
- 根据已确认设计文档批量创建文件
- 把重复性说明整理成 Markdown（在「禁止扩写未实现功能」约束下）
- 协助排查「命令行/构建配置」类问题（仍需人验证）

## 8.2 哪些工作必须人工判断

- 生物学流程是否可接受（要不要 MSA、距离定义、建树假设）
- MVP 范围裁剪（做什么、明确不做什么）
- 模块边界与「禁止修改」清单
- 测试是否测到了正确语义（而不仅是 happy path）
- 文档与代码一致性审查
- 最终演示数据的结果解释（拓扑是否「看起来合理」）

## 8.3 如何拆分任务

推荐拆法（本项目已验证）：

1. **目录与配置** → 可运行空壳  
2. **纯函数/可单测算法** → Parser、Calculator、Builder、Writer  
3. **Service 编排 + 文件产物** → 可脱离 HTTP 验证  
4. **本地 Runner** → 全量真实数据冒烟  
5. **REST** → 契约冻结后再给前端  
6. **UI** → 只消费契约  

每一步的输入输出最好是**磁盘文件或测试断言**，而不是「感觉差不多」。

## 8.4 如何验证 AI 输出

建议检查清单：

1. **静态**：新增了哪些文件？有没有改到冻结模块？  
2. **单测**：关键数值算例是否覆盖？  
3. **产物**：CSV/NWK 是否存在、维度/叶数是否与输入一致？  
4. **接口**：status code + JSON 字段是否与约定一致？  
5. **端到端**：Runner 或页面是否真能走通？  
6. **语义**：注释/文档是否诚实标注了 MVP 限制？  
7. **否定检查**：有没有偷偷加入数据库、MSA 空壳、无关重构？

一句话：**AI 负责加速实现，人负责定义完成标准与科学边界。**

---

## 附录 A：后端关键类速查（实现态）

| 模块 | 类 |
|------|----|
| FASTA | `FastaRecord`, `FastaParser`, `FastaService`, `SequenceController` |
| 矩阵 | `DistanceMatrix`, `PDistanceCalculator`, `DistanceMatrixService`, `DistanceMatrixCsvWriter`, `DistanceMatrixCsvReader` |
| 树 | `TreeNode`, `PhylogeneticTree`, `UpgmaBuilder`, `NewickWriter`, `TreeService` |
| API | `AnalysisController`, `AnalysisRunResponse`, `DistanceMatrixResponse`, `TreeResponse` |
| 本地验证 | `AnalysisRunner` + Gradle `runAnalysis` |

## 附录 B：前端关键文件速查（实现态）

| 文件 | 职责 |
|------|------|
| `api/http.js` | Axios baseURL |
| `api/analysis.js` | 三个 analysis API |
| `App.vue` | 分析按钮与结果编排 |
| `DistanceMatrixTable.vue` | 矩阵表 |
| `PhylogeneticTreeView.vue` + `TreeBranch.vue` | 简易树 |
| `utils/newick.js` | Newick 解析 |

## 附录 C：已验证的本地命令（开发期常用）

```bash
# 后端测试
cd backend && gradle test

# 无 HTTP 全流程
cd backend && gradle runAnalysis

# 后端服务
cd backend && gradle bootRun

# 前端
cd frontend && npm install && npm run dev
```

API 冒烟：

```bash
curl -X POST http://localhost:8080/api/analysis/run
curl http://localhost:8080/api/analysis/matrix
curl http://localhost:8080/api/analysis/tree
```

---

## 附录 D：复盘结论（压缩版）

本项目作为 **MVP Demo** 已打通「FASTA →（截断）p-distance → UPGMA → Newick → REST → Vue」链路，工程分层与模块测试是主要收获；最大技术债是 **缺少 MSA 导致距离科学基础不完整**，以及文档与实现部分不同步。Cursor 辅助开发在本项目中的成功关键，不在于「一次生成整个平台」，而在于：**设计确认、范围冻结、小步提交、产物验证、禁止改已测代码** 这套人机分工。

若只记一条经验：先让流水线在文件系统上诚实跑通，再包 API 与 UI；先承认 MVP 的生物学简化，再谈平台化与可视化升级。

---

*文档结束。*
