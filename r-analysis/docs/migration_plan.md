# r-analysis 生产化迁移计划

> 生成日期：2026-07-24  
> 依据：[`directory_audit.md`](directory_audit.md)、[`cleanup_plan.md`](cleanup_plan.md)  
> 原则：**不删除任何文件；本文件仅设计，不执行移动/改代码。**

### 目标约束

1. 保留 H3N2 HA benchmark **完整可复现**流程  
2. 保留 demo / 冒烟测试能力  
3. 为未来 Spring Boot 多脚本调用准备**稳定目录契约**  
4. 「可删除」类一律迁入 `archive/`，**物理删除留待人工确认后再做**

---

## 1. 推荐的新目录树

```text
r-analysis/
│
├── README.md                          # 更新路径说明（迁移执行时改）
├── docs/                              # 审计与计划文档集中
│   ├── directory_audit.md
│   ├── cleanup_plan.md
│   └── migration_plan.md              # 本文件
│
├── config/                            # 预留：Boot / 本地路径约定
│   ├── .gitkeep
│   └── r-engine.paths.example.md      # （可选新建）文档化 CLI 与相对路径
│
├── engine/                            # ★ Spring Boot 正式调用入口（稳定契约）
│   ├── phylogenetic_tree.R            # 已对接 / 保持 CLI 不变
│   ├── ggtree_visualization.R         # P0 待对接
│   ├── ncbi_metadata_to_tree_metadata.R
│   └── add_bootstrap_labels_only.R    # P1
│
├── scripts/                           # 人工编排 / 数据准备 / demo（非 Boot 热路径）
│   ├── prep/
│   │   ├── parse_ncbi_genbank_ha.R
│   │   ├── prepare_h3n2_ha_benchmark.R
│   │   ├── report_h3n2_benchmark.R
│   │   └── prepare_platform_fasta.R
│   ├── demo/
│   │   ├── prepare_circular_demo.R
│   │   └── plot_circular_tree.R       # 旧 circular；保留 demo 能力
│   └── runners/
│       ├── run_h3n2_ha_benchmark.ps1
│       ├── run_ggtree_viz.ps1
│       ├── run_test_example.ps1
│       ├── run_test_real_data.ps1
│       └── run_circular_demo.ps1
│
├── data/
│   ├── smoke/
│   │   └── example.fasta              # 玩具冒烟
│   ├── demo/
│   │   ├── circular/
│   │   │   ├── tree.nwk
│   │   │   └── metadata.csv
│   │   ├── example_metadata.csv
│   │   └── example_metadata_6tips.csv
│   └── benchmarks/
│       └── h3n2_ha/                   # ★ 正式可复现基准输入
│           ├── h3n2_ha_unaligned.fasta
│           ├── ncbi_metadata.csv
│           └── sampling_report.txt
│
├── test-data/                         # 真实/平台冒烟（保留能力；结构微调）
│   ├── README.md
│   ├── fixtures/                      # 测试用 FASTA 集中
│   │   ├── platform_16s.fasta
│   │   ├── platform_16s_equal_len.fasta
│   │   └── h3n2_na_20.fasta           # 或迁 archive（见分类）
│   ├── input.fasta                    # （可选，用户自放；约定不变）
│   └── output/
│       └── .gitkeep
│
├── output/
│   ├── .gitkeep
│   ├── tasks/                         # ★ Spring Boot 每任务子目录落点
│   │   └── .gitkeep                   # 例：tasks/{runId}/
│   ├── benchmarks/
│   │   └── h3n2_ha/                   # ★ 正式基准成功产物（整目录保留）
│   │       ├── tree.nwk
│   │       ├── tree.png
│   │       ├── distance_matrix.csv
│   │       ├── analysis_result.json
│   │       ├── metadata.csv
│   │       ├── circular_tree_final.png
│   │       ├── circular_tree_final.pdf
│   │       ├── visualization_report.json
│   │       ├── benchmark_report.txt
│   │       └── （过渡命名 circular_tree_distance.* 可随目录保留或进 archive）
│   └── demos/
│       └── circular/                  # demo 出图
│           ├── circular_tree.png
│           └── circular_tree.pdf
│
├── tools/                             # 运行时二进制（Boot 部署需打包）
│   ├── muscle.exe
│   └── mafft-win/                     # 厂商树整体不动
│
└── archive/                           # ★ 不删除：历史 / 探针 / 安装包
    ├── README.md                      # 说明「观察期后再物理删除」
    ├── 2026-07-24/
    │   ├── data/
    │   │   └── ncbi_h3n2_ha/          # 早期 NCBI 中间产物整树
    │   ├── output/
    │   │   ├── root_run/              # 原 output/ 根目录小跑通产物
    │   │   ├── h3n2_real/
    │   │   ├── probes/                # _probe_*.png
    │   │   ├── smoke/                 # _smoke_*.fasta（原 benchmark 内）
    │   │   └── ggtree_install_failure.txt
    │   ├── tools/
    │   │   ├── mafft-7.526-win64-signed.zip
    │   │   ├── mafft-fresh.zip
    │   │   ├── _smoke.fa
    │   │   ├── _smoke_muscle.fa
    │   │   └── mafft-extract/         # 空目录
    │   ├── misc/
    │   │   ├── Rplots.pdf             # 根 + scripts 两份
    │   │   ├── tmp_aplot_0.2.9.zip
    │   │   └── config_empty/          # 原空 config/ 若被替代
    │   └── backups/
    │       └── tree.nwk.bak_nobootstrap
    └── ...
```

### 设计要点

| 决策 | 理由 |
|------|------|
| `engine/` 与 `scripts/` 分离 | Boot 只依赖 `engine/`；人工 prep/demo/runners 可演进而不污染契约 |
| `data/benchmarks/h3n2_ha` | 明确「可复现科研输入」；与 smoke/demo 分离 |
| `output/tasks/` | 为 Java 预留 `{outputDir}=.../output/tasks/{runId}` |
| `output/benchmarks/h3n2_ha` | 正式基准产物固定位置，不被任务输出冲掉 |
| `archive/` 替代物理删除 | 满足「不删除任何文件」；清理可分两阶段 |
| `tools/` 路径尽量不变 | `phylogenetic_tree.R` 已按 `../tools` 查找；`engine/` 下仍是 `../tools` |

### 与现状对比（契约路径）

| 角色 | 现状 | 推荐 |
|------|------|------|
| 建树脚本 | `scripts/phylogenetic_tree.R` | `engine/phylogenetic_tree.R` |
| 基准输入 | `data/ncbi_h3n2_ha_benchmark/` | `data/benchmarks/h3n2_ha/` |
| 基准输出 | `output/h3n2_ha_benchmark/` | `output/benchmarks/h3n2_ha/` |
| 玩具 FASTA | `data/example.fasta` | `data/smoke/example.fasta` |
| circular demo 输入 | `data/circular_demo/` | `data/demo/circular/` |
| Boot 任务输出 | 任意 / 常写 `output/` 根 | `output/tasks/{runId}/` |

> **兼容备选（更少 Java 改动）**：若希望暂不改 `phylo.r.script`，可把 `engine/` 改为仍叫 `scripts/`，仅把 prep/demo/runners 下沉到子目录，核心 4 个 R 文件留在 `scripts/` 根。下文「路径修改」两套都列出。

---

## 2. 每个文件移动建议

图例：`→` 目标路径；`—` 原地保留；`archive` = 迁入 `archive/2026-07-24/...`

### 2.1 文档 / 杂项

| 当前路径 | 移动建议 |
|----------|----------|
| `README.md` | — 保留根目录；内容在执行阶段更新 |
| `directory_audit.md` | → `docs/directory_audit.md` |
| `cleanup_plan.md` | → `docs/cleanup_plan.md` |
| `migration_plan.md`（本文件） | → `docs/migration_plan.md`（或生成时已在 docs） |
| `Rplots.pdf` | → `archive/2026-07-24/misc/Rplots.pdf` |
| `tmp_aplot_0.2.9.zip` | → `archive/2026-07-24/misc/tmp_aplot_0.2.9.zip` |
| `config/`（空） | 重建为带 `.gitkeep` 的正式 `config/`；原空壳可 → `archive/.../config_empty/` |

### 2.2 脚本 → `engine/` / `scripts/*`

| 当前路径 | 移动建议 |
|----------|----------|
| `scripts/phylogenetic_tree.R` | → `engine/phylogenetic_tree.R` |
| `scripts/ggtree_visualization.R` | → `engine/ggtree_visualization.R` |
| `scripts/ncbi_metadata_to_tree_metadata.R` | → `engine/ncbi_metadata_to_tree_metadata.R` |
| `scripts/add_bootstrap_labels_only.R` | → `engine/add_bootstrap_labels_only.R` |
| `scripts/parse_ncbi_genbank_ha.R` | → `scripts/prep/parse_ncbi_genbank_ha.R` |
| `scripts/prepare_h3n2_ha_benchmark.R` | → `scripts/prep/prepare_h3n2_ha_benchmark.R` |
| `scripts/report_h3n2_benchmark.R` | → `scripts/prep/report_h3n2_benchmark.R` |
| `scripts/prepare_platform_fasta.R` | → `scripts/prep/prepare_platform_fasta.R` |
| `scripts/prepare_circular_demo.R` | → `scripts/demo/prepare_circular_demo.R` |
| `scripts/plot_circular_tree.R` | → `scripts/demo/plot_circular_tree.R` |
| `scripts/run_h3n2_ha_benchmark.ps1` | → `scripts/runners/run_h3n2_ha_benchmark.ps1` |
| `scripts/run_ggtree_viz.ps1` | → `scripts/runners/run_ggtree_viz.ps1` |
| `scripts/run_test_example.ps1` | → `scripts/runners/run_test_example.ps1` |
| `scripts/run_test_real_data.ps1` | → `scripts/runners/run_test_real_data.ps1` |
| `scripts/run_circular_demo.ps1` | → `scripts/runners/run_circular_demo.ps1` |
| `scripts/Rplots.pdf` | → `archive/2026-07-24/misc/scripts_Rplots.pdf` |

### 2.3 数据

| 当前路径 | 移动建议 |
|----------|----------|
| `data/example.fasta` | → `data/smoke/example.fasta` |
| `data/example_metadata.csv` | → `data/demo/example_metadata.csv` |
| `data/example_metadata_6tips.csv` | → `data/demo/example_metadata_6tips.csv` |
| `data/circular_demo/tree.nwk` | → `data/demo/circular/tree.nwk` |
| `data/circular_demo/metadata.csv` | → `data/demo/circular/metadata.csv` |
| `data/ncbi_h3n2_ha_benchmark/*` | → `data/benchmarks/h3n2_ha/*`（整目录改名迁移） |
| `data/ncbi_h3n2_ha/**` | → `archive/2026-07-24/data/ncbi_h3n2_ha/**` |

### 2.4 输出

| 当前路径 | 移动建议 |
|----------|----------|
| `output/.gitkeep` | —；并新增 `output/tasks/.gitkeep` |
| `output/h3n2_ha_benchmark/**`（正式成品） | → `output/benchmarks/h3n2_ha/**` |
| `output/h3n2_ha_benchmark/circular_tree_distance.*` | 随目录迁移，或单独 → `archive/.../output/legacy_names/` |
| `output/h3n2_ha_benchmark/tree.nwk.bak_nobootstrap` | → `archive/2026-07-24/backups/tree.nwk.bak_nobootstrap` |
| `output/h3n2_ha_benchmark/_smoke_*.fasta` | → `archive/2026-07-24/output/smoke/` |
| `output/circular_demo/*` | → `output/demos/circular/*` |
| `output/h3n2_real/**` | → `archive/2026-07-24/output/h3n2_real/**` |
| `output/tree.nwk`, `tree.png`, `distance_matrix.csv`, `analysis_result.json`, `metadata.csv`, `visualization_report.json`, `circular_tree_final.*`, `circular_tree.*`, `circular_tree_distance.*` | → `archive/2026-07-24/output/root_run/` |
| `output/_probe_*.png`（6） | → `archive/2026-07-24/output/probes/` |
| `output/ggtree_install_failure.txt` | → `archive/2026-07-24/output/` |

### 2.5 test-data

| 当前路径 | 移动建议 |
|----------|----------|
| `test-data/README.md` | —（更新文内路径） |
| `test-data/output/.gitkeep` | — |
| `test-data/platform_16s.fasta` | → `test-data/fixtures/platform_16s.fasta` |
| `test-data/platform_16s_equal_len.fasta` | → `test-data/fixtures/platform_16s_equal_len.fasta` |
| `test-data/h3n2_na_20.fasta` | → `test-data/fixtures/h3n2_na_20.fasta` **或** → `archive/.../test-data/`（见 §3） |

### 2.6 tools

| 当前路径 | 移动建议 |
|----------|----------|
| `tools/muscle.exe` | — |
| `tools/mafft-win/**` | —（整树保留） |
| `tools/mafft-7.526-win64-signed.zip` | → `archive/2026-07-24/tools/` |
| `tools/mafft-fresh.zip` | → `archive/2026-07-24/tools/` |
| `tools/_smoke.fa` | → `archive/2026-07-24/tools/` |
| `tools/_smoke_muscle.fa` | → `archive/2026-07-24/tools/` |
| `tools/mafft-extract/` | → `archive/2026-07-24/tools/mafft-extract/` |

---

## 3. 保留 / 归档 / 删除分类

> 「删除」在本计划中 = **迁入 archive 后标记可物理删除**；执行迁移时仍不真正 `rm`。

### 第一类：保留（生产 / 可复现 / Boot）

| 路径（迁移后） | 说明 |
|----------------|------|
| `engine/*.R`（4） | Boot + 正式 pipeline |
| `scripts/prep/*` | 基准可再生 |
| `scripts/demo/*` | 保留 demo 能力 |
| `scripts/runners/*` | 一键复现 / 冒烟 |
| `data/smoke/example.fasta` | 冒烟 |
| `data/demo/**` | demo 输入 |
| `data/benchmarks/h3n2_ha/**` | H3N2 可复现输入 |
| `output/benchmarks/h3n2_ha/` 正式成品（不含 smoke/bak） | 基准成功产物 |
| `output/demos/circular/` | demo 出图能力 |
| `output/tasks/` | Boot 落点 |
| `test-data/README.md`, `fixtures/platform_16s*.fasta`, `output/.gitkeep` | 冒烟 |
| `tools/muscle.exe`, `tools/mafft-win/` | 比对依赖 |
| `README.md`, `docs/*`, `config/.gitkeep` | 文档与配置位 |

### 第二类：归档（迁入 `archive/`，保留可追溯）

| 当前 / 建议 | 说明 |
|-------------|------|
| `data/ncbi_h3n2_ha/**` | 早期 NCBI 链路 |
| `output/h3n2_real/**` | 小规模实跑 |
| 根 `output/` 小跑通与旧命名 circular | 非正式任务产物 |
| `output/h3n2_ha_benchmark/circular_tree_distance.*` | 过渡命名（可选归档） |
| `tree.nwk.bak_nobootstrap` | 备份 |
| MAFFT 两个 zip、`tmp_aplot_*.zip` | 安装残留 |
| `test-data/h3n2_na_20.fasta` | 可选：保留在 fixtures 或归档（非 HA 基准） |

### 第三类：标记可删除（仅 archive 后；本阶段不删）

| 项 | 说明 |
|----|------|
| `_probe_*.png` ×6 | 调试探针 |
| `_smoke_*.fasta` / `tools/_smoke*.fa` | smoke 残留 |
| `Rplots.pdf`（根与 scripts） | 偶然产物 |
| `ggtree_install_failure.txt` | 失败日志 |
| 空 `config/` / `mafft-extract/` | 空壳 |

---

## 4. 移动后：R / ps1 / Java 路径是否需要修改

### 4.1 总表

| 文件 | 是否必须改路径 | 改什么 |
|------|----------------|--------|
| `engine/phylogenetic_tree.R` | **弱依赖** | `tools` 查找：`file.path(script_dir,"..","tools")` 在 `engine/` 下仍正确。用法示例字符串 `../data/example.fasta` → 建议改为 `../data/smoke/example.fasta`（仅文档/报错提示） |
| `engine/ggtree_visualization.R` | **否** | 纯 CLI 参数；无仓库内硬编码数据路径 |
| `engine/ncbi_metadata_to_tree_metadata.R` | **否** | 纯 CLI |
| `engine/add_bootstrap_labels_only.R` | **是** | `source(file.path(scripts_dir,"phylogenetic_tree.R"))` → 同目录 `phylogenetic_tree.R`（若同迁 `engine/` 则改为 `source(file.path(scripts_dir,"phylogenetic_tree.R"))` 仍正确；若曾跨目录则必须改） |
| `scripts/prep/parse_ncbi_genbank_ha.R` | **否** | CLI only |
| `scripts/prep/prepare_h3n2_ha_benchmark.R` | **是** | 默认 `out_dir`：`../data/ncbi_h3n2_ha_benchmark` → `../../data/benchmarks/h3n2_ha`（注意多一层 `prep/`） |
| `scripts/prep/report_h3n2_benchmark.R` | **是（建议）** | 默认 `output/h3n2_ha_benchmark` → `../../output/benchmarks/h3n2_ha`；`circular_tree_distance.png` → `circular_tree_final.png`（命名债一并修） |
| `scripts/prep/prepare_platform_fasta.R` | **是** | `r_root` 仍为 `scripts/prep/../..` = `r-analysis`（需从 `script_dir` 上两级）；`out_fasta` → `test-data/fixtures/platform_16s.fasta`；`raw_dir` 仍 `../../data/raw`（仓库根 `data/raw`） |
| `scripts/demo/prepare_circular_demo.R` | **是** | `data/circular_demo` → `data/demo/circular`；`example_metadata.csv` → `data/demo/example_metadata.csv`；`script_dir` 上溯改为 `../..` |
| `scripts/demo/plot_circular_tree.R` | **否** | CLI only |
| `scripts/runners/run_h3n2_ha_benchmark.ps1` | **是** | 见下节完整重写映射 |
| `scripts/runners/run_ggtree_viz.ps1` | **是** | `$Root` 计算、engine 路径、默认改为 `output/tasks/latest` 或显式参数 |
| `scripts/runners/run_test_example.ps1` | **是** | `data/smoke/example.fasta`；`engine/phylogenetic_tree.R`；`$Root` 上溯两级 |
| `scripts/runners/run_test_real_data.ps1` | **是** | fixtures 路径；调用 `prep/prepare_platform_fasta.R` 与 `engine/...` |
| `scripts/runners/run_circular_demo.ps1` | **是** | demo 数据/输出路径；调用 `demo/*.R` |
| `backend/.../application.properties` | **是** | `phylo.r.script=../r-analysis/engine/phylogenetic_tree.R` |
| `PhyloRProperties.java` 默认值 | **是** | 同上默认字符串 |
| `README.md` / `test-data/README.md` | **是** | 文档路径全面更新 |

### 4.2 `run_h3n2_ha_benchmark.ps1` 路径映射（可复现关键）

| 现状 | 迁移后 |
|------|--------|
| `$Root = ...\r-analysis`（现由 `scripts` 上一级） | `$Root = Resolve-Path (Join-Path $ScriptDir ..\..)`（runners 上两级） |
| `data\ncbi_h3n2_ha_benchmark\h3n2_ha_unaligned.fasta` | `data\benchmarks\h3n2_ha\h3n2_ha_unaligned.fasta` |
| `data\ncbi_h3n2_ha_benchmark\ncbi_metadata.csv` | `data\benchmarks\h3n2_ha\ncbi_metadata.csv` |
| `output\h3n2_ha_benchmark` | `output\benchmarks\h3n2_ha` |
| `scripts\phylogenetic_tree.R` | `engine\phylogenetic_tree.R` |
| `scripts\ncbi_metadata_to_tree_metadata.R` | `engine\ncbi_metadata_to_tree_metadata.R` |
| `scripts\ggtree_visualization.R` | `engine\ggtree_visualization.R` |
| `scripts\report_h3n2_benchmark.R` | `scripts\prep\report_h3n2_benchmark.R` |
| `tools` / `tools\mafft-win` PATH | **不变**（仍相对 `$Root`） |

迁移后基准一键命令（设计约定，未执行）：

```powershell
cd r-analysis\scripts\runners
.\run_h3n2_ha_benchmark.ps1
```

### 4.3 Spring Boot 契约（未来）

| 配置键（建议） | 值 |
|----------------|-----|
| `phylo.r.script` | `../r-analysis/engine/phylogenetic_tree.R` |
| `phylo.r.viz-script`（新增） | `../r-analysis/engine/ggtree_visualization.R` |
| `phylo.r.metadata-script`（新增） | `../r-analysis/engine/ncbi_metadata_to_tree_metadata.R` |
| 任务输出目录 | `../r-analysis/output/tasks/{runId}` |

期望任务目录契约：

```text
output/tasks/{runId}/
  analysis_result.json
  tree.nwk
  distance_matrix.csv
  tree.png
  metadata.csv                 # 若跑 metadata 步
  circular_tree_final.png/pdf  # 若跑 viz 步
  visualization_report.json
```

基准目录 `output/benchmarks/h3n2_ha/` **不要**被 API 任务覆盖。

### 4.4 可不改路径的脚本（若采用「兼容备选」）

若核心 4 个 R 文件仍留在 `scripts/` 根、仅移动 prep/demo/runners：

- `application.properties` **可不改**
- `phylogenetic_tree.R` 的 `tools` 查找 **可不改**
- 仍必须改：所有 runners、`prepare_*` 默认路径、demo 数据路径、基准 data/output 重命名

---

## 5. 推荐执行阶段（仍不自动执行）

| 阶段 | 动作 | 风险 |
|------|------|------|
| A. 建骨架 | 创建 `engine/`、`scripts/{prep,demo,runners}`、`data/{smoke,demo,benchmarks}`、`output/{tasks,benchmarks,demos}`、`archive/2026-07-24/`、`docs/` | 低 |
| B. 迁基准 | 整目录移动 `ncbi_h3n2_ha_benchmark` → `data/benchmarks/h3n2_ha`；`output/h3n2_ha_benchmark` → `output/benchmarks/h3n2_ha` | 中：必须同步改 `run_h3n2_ha_benchmark.ps1` |
| C. 迁 engine | 4 个核心 R → `engine/`；改 Java `phylo.r.script` | 中：Boot 联调 |
| D. 迁 demo/smoke | 数据与 demo 脚本；改 runners | 低 |
| E. 归档杂物 | probe/smoke/zip/早期 NCBI → `archive/` | 低 |
| F. 验证 | ① `run_test_example.ps1` ② `run_circular_demo.ps1` ③ `run_h3n2_ha_benchmark.ps1` ④ Boot `/api/r-analysis` | 必须全绿再谈物理删 archive |

### 验收清单（设计）

- [ ] H3N2：从 `data/benchmarks/h3n2_ha` 复现出与现 `circular_tree_final.*` 同结构产物  
- [ ] Demo：`run_circular_demo.ps1` 仍能出图  
- [ ] Smoke：`example.fasta` 冒烟成功  
- [ ] Boot：仅改配置路径后建树 API 仍通  
- [ ] `archive/` 中可见全部「可删」项，工作树无物理删除  

---

## 6. 明确不做的事（本计划）

- 不执行 `git mv` / 复制 / 删除  
- 不修改任何 `.R` / `.ps1` / Java 代码  
- 不物理删除 `archive/` 内容  
- 不改动 `tools/mafft-win/` 内部结构  

---

## 7. 一句话结论

把 **Boot 契约**收拢到 `engine/` + `output/tasks/`，把 **H3N2 可复现基准**固定到 `data|output/benchmarks/h3n2_ha/`，把 **demo/冒烟**放到 `data/demo|smoke` + `scripts/demo|runners`，其余历史与探针进 `archive/`——在改完 §4 所列路径后即可保持三条目标全部成立。
