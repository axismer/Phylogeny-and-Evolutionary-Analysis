# Framework v0.3 P2 Plan — Core IO 抽取

> 日期：2026-07-24  
> 状态：**已完成（2026-07-24）— 不进入 P3**  
> 前置：P1 Error Contract 已完成（v02 13/13 + P1 5/5）  
> 回归：v02 13/13 + P1 5/5 + P2 10/10

---

## 0. 约束

| 禁止 | 必须保持 |
|------|----------|
| 改 `engine/` | success JSON 字段兼容（无新增强制键；仍禁止 success 带 `error_code`） |
| 改 H3N2 / bacteria benchmark | CLI 参数不变 |
| 改 Spring Boot / 前端 | tip label / 树结果语义不变 |
| 实现 archaea/eukaryote | v02 + P1 回归继续绿 |
| 大量新增 error_code | 仅用已有码（见下） |

允许使用的 error_code（本阶段）：

- `EMPTY_FASTA`
- `INVALID_DNA`（仅当 strategy 调用方做碱基校验时；IO 层 basic 可不抛此码）
- `METADATA_FILE_NOT_FOUND`
- `MISSING_METADATA_ARGUMENT`

IO 层**不**新增码表项。

---

## 1. 当前重复位置

### 1.1 FASTA

| 位置 | 重复内容 |
|------|----------|
| `strategies/virus/virus_strategy.R` | 内联 `read_fasta_records()`（~25 行） |
| `strategies/bacteria/bacteria_strategy.R` | **同名同逻辑** `read_fasta_records()` |
| 两者 `validate_input` | `file.exists` / 空文件 / `readLines` 探测 / 首行 `>` 检查高度相似 |

生物学差异（应留在 strategy，**不**抽进 basic IO）：

- bacteria：IUPAC、最少 3 条、长度启发式、过短 `<50`
- virus：最少 3 条、IUPAC（P1 已加）

### 1.2 Metadata

| 位置 | 重复内容 |
|------|----------|
| virus `parse_metadata` | `file.exists` + `utils::read.csv` |
| bacteria `parse_metadata` | 同上 + `assert_bacteria_metadata_columns` / `validate_metadata` |
| `metadata/metadata_validator.R` | 已有 `validate_metadata_file(path, organism_type, strict)`（读 CSV + 校验） |

注意：任务要求 `metadata_io.R` 提供 `validate_metadata_file()` —— 与现有 `metadata/metadata_validator.R` **同名**。  
计划采用：

- `core/io/metadata_io.R::read_metadata()` — 统一读 CSV + 路径/参数错误 → `raise_framework_error`
- `core/io/metadata_io.R::validate_metadata_path()` 或包装名 **`ensure_metadata_readable()`**  
  若必须暴露名为 `validate_metadata_file`：在 io 层实现为「路径存在性 + 可读性」薄封装，**委托**既有 `metadata::validate_metadata` / 避免覆盖 validator 语义；或命名为 `read_and_validate_metadata()` 并在计划确认中说明。

**建议（待确认）：** io 层函数名为：

- `read_metadata(path)`  
- `require_metadata_argument(path)` → 缺参 `MISSING_METADATA_ARGUMENT`  
- `read_metadata_or_fail(path)` → 文件不存在 `METADATA_FILE_NOT_FOUND`  
- 类型 schema 校验仍调用现有 `validate_metadata()`（不搬进 io）

若坚持字面 `validate_metadata_file`：io 版仅做「文件可读」，与 validator 的 `validate_metadata_file` 区分命名空间（加载顺序：先 validator，io 用别名 `io_validate_metadata_file`）。**默认方案：不覆盖 validator，io 用 `read_metadata` + `require_metadata_path`。**

### 1.3 Output JSON

| 位置 | 现状 |
|------|------|
| virus/bacteria `run` 成功收尾 | 直接 `write_analysis_result(result, ctx$output_dir)` |
| `core/result_writer.R` | 已有 UTF-8 `write_analysis_result` / `write_error_analysis_result` |

`output_io.R` 将做薄包装，**不复制** JSON 序列化逻辑。

---

## 2. 准备抽取的函数

### 2.1 `core/io/fasta_io.R`

| 函数 | 行为 |
|------|------|
| `read_fasta(path)` | 返回 `list(ids=, seqs=)`；逻辑与现 `read_fasta_records` **逐行一致**（tip 不变） |
| `validate_fasta_basic(path)` | 存在、非空、至少一行以 `>` 开头；失败 → `EMPTY_FASTA` |
| `write_fasta(path, ids, seqs)` | 写出 FASTA（供测试/对称 API；strategy 生产路径可不调用） |

**不**放入 basic：IUPAC、min_sequences=3（留 strategy，可继续 `raise_framework_error(INVALID_DNA|TOO_FEW_SEQUENCE)`）。

### 2.2 `core/io/metadata_io.R`

| 函数 | 行为 |
|------|------|
| `read_metadata(path)` | `utils::read.csv(..., stringsAsFactors=FALSE, check.names=FALSE)`；失败/不存在 → `METADATA_FILE_NOT_FOUND` |
| `require_metadata_argument(path)` | `NULL`/空 → `MISSING_METADATA_ARGUMENT` |
| （可选）`validate_metadata_file` 包装 | 见 §1.2 命名决议 |

### 2.3 `core/io/output_io.R`

| 函数 | 行为 |
|------|------|
| `safe_write_json(obj, path)` | UTF-8 写出（可委托 jsonlite；错误 → 框架错误或保留现 writer 行为） |
| `write_analysis_output(result, output_dir)` | 委托 `write_analysis_result`；保证 success 无 `error_code` |

---

## 3. 准备修改的文件

| 文件 | 改动 |
|------|------|
| **新增** `core/io/fasta_io.R` | 上表 |
| **新增** `core/io/metadata_io.R` | 上表 |
| **新增** `core/io/output_io.R` | 上表 |
| `strategies/virus/virus_strategy.R` | 删除内联 `read_fasta_records`；`validate_input`/`parse_metadata` 调 core/io；成功写出调 `write_analysis_output` |
| `strategies/bacteria/bacteria_strategy.R` | 同上 |
| `core/strategy_runner.R` 或 `result_writer.R` | **自举 source** `core/io/*.R`（避免本阶段大改 registry；与 P1 error_codes 模式一致） |
| **可选** `strategies/strategy_registry.R` | 仅增加 io 文件到 `source_framework_core` 列表（一行级）；**非必须** |
| **新增** `scripts/runners/run_framework_v03_p2_regression.R` | P2 回归 |
| **新增** `docs/framework_v03_p2_report.md` | 完成后写 |

**不修改：** `engine/**`、benchmark、Boot、前端、archaea/eukaryote 实现、plugin 注册机制（P3）。

---

## 4. 迁移映射（strategy 侧）

```text
旧 read_fasta_records(path)
  → read_fasta(path)

旧 空/存在/首行检查
  → validate_fasta_basic(path)   # 然后 strategy 再做 DNA / min_n

旧 utils::read.csv(metadata)
  → read_metadata(path)          # 或 require + read

旧 write_analysis_result(result, dir)
  → write_analysis_output(result, dir)
```

禁止：strategy 内业务失败再写裸 `stop("xxx")`（P1 已改为 `raise_framework_error`；P2 保持）。

---

## 5. 风险

| 风险 | 等级 | 缓解 |
|------|------|------|
| FASTA 解析细微差别导致 tip 变化 | **高** | 从 bacteria/virus 现有函数**原样搬迁**；P2 后对比 tip 集合 / 跑 valid |
| 覆盖 `validate_metadata_file` 名冲突 | 中 | 默认不覆盖；见 §1.2 |
| io 未加载导致 `read_fasta` 找不到 | 中 | strategy_runner/result_writer 自举；回归立刻暴露 |
| `write_analysis_output` 误改 success 字段 | 中 | 薄委托现有 writer；P1/P2 断言无 `error_code` |
| bacteria empty 文案回归 | 低 | 保持 P1 兼容文案（含「至少需要 3」） |

---

## 6. 测试方案

### 必跑（兼容）

```bash
cd r-analysis
Rscript scripts/runners/run_framework_regression.R      # 期望 13/13
Rscript scripts/runners/run_framework_v03_p1_regression.R  # 期望 5/5
```

### 新增 `framework_v03_p2_regression`

输出：`output/tasks/framework_v03_p2_regression/summary.json`

| case | expect |
|------|--------|
| virus valid | exit 0；success/partial；无 error_code |
| virus bad fasta | exit 1；error（EMPTY_FASTA 或既有坏 FASTA 行为） |
| virus missing metadata | 传不存在的 metadata 路径 → exit 1；`METADATA_FILE_NOT_FOUND` |
| bacteria valid | exit 0；无 error_code |
| bacteria bad metadata | missing_fields → exit 1；`MISSING_METADATA_FIELDS`（既有） |
| bacteria missing fasta | 不存在的 fasta 路径 → exit 1；`EMPTY_FASTA`（与 P1 码表一致） |

---

## 7. 回滚方案

| 级别 | 动作 |
|------|------|
| P2 失败 | 还原 `virus_strategy` / `bacteria_strategy`；删除或停用 `core/io/`；重跑 v02+P1 |
| 仅 tip 漂移 | 回滚 `fasta_io.R` 至内联副本；strategy 恢复本地函数 |
| 全量 | 回到 P1 完成态提交；保留本 plan 文档 |

---

## 8. 实施步骤（确认后）

1. 新增 `core/io/{fasta,metadata,output}_io.R`（从现实现拷贝解析逻辑）  
2. strategy_runner/result_writer 自举加载 io  
3. 迁移 virus → 冒烟 virus valid  
4. 迁移 bacteria → 冒烟 bacteria valid  
5. 跑 v02 + P1 + 新增 P2 回归  
6. 写 `docs/framework_v03_p2_report.md`  
7. **停止，不进入 P3**

---

## 9. 请确认

1. **同意** `validate_fasta_basic` 不含 DNA/最少 3 条（生物学仍在 strategy）？  
2. **同意** metadata io **不覆盖** 现有 `metadata_validator::validate_metadata_file`，改用 `read_metadata` / `require_metadata_argument`？  
3. **同意** 本阶段用自举加载 `core/io`，**不改** registry（留给 P3）？  
4. **同意** 按上表 6 案 P2 回归？  

回复「确认，开始 P2 编码」或修订意见后，再改代码。
