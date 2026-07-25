# Framework Progress Report — Multi-Organism v0.1

> 日期：2026-07-24  
> 阶段：v0.1 冻结完成 + Hardening 文档审计（本报告）  
> 范围：`r-analysis` 多生物类型框架  
> **本 Hardening 阶段未修改** `engine/`、`strategies/virus/`、`strategies/bacteria/` 代码

---

## 1. 已完成

### 1.1 框架与生产能力

| 项 | 状态 |
|----|------|
| Strategy Pattern（`PhyloAnalysisStrategy`） | 完成 |
| 统一 CLI `runners/run_analysis.R` | 完成 |
| Virus 生产路径（委托 legacy engine + ggtree） | 完成 |
| Bacteria 生产路径（委托 legacy engine + bacteria viz） | 完成 |
| Archaea / Eukaryote 骨架 `not_implemented` | 完成（exit 2） |
| `analysis_result.json` v0.1 契约冻结 | 完成 |
| Virus/Bacteria 失败写 error JSON | 完成 |
| Metadata schema + validator | 完成（bacteria 另有严格列断言） |
| H3N2 / bacteria 基准与验证文档 | 完成（历史工作） |

### 1.2 冻结与 Hardening 文档

| 文档 | 用途 |
|------|------|
| `docs/analysis_result_contract.md` | JSON / status / exit 冻结 |
| `docs/framework_freeze_report.md` | v0.1 冻结报告 |
| `docs/framework_architecture_audit.md` | **本阶段**架构审计 |
| `docs/new_organism_development_guide.md` | **本阶段**新类型接入规范 |
| `docs/error_handling_audit.md` | **本阶段**异常路径审计 |
| `docs/framework_test_matrix.md` | **本阶段**测试矩阵 |
| `docs/framework_progress_report_v0.1.md` | **本报告** |

### 1.3 回归

`scripts/runners/run_framework_regression.R`：**6/6 PASS**（virus×3 + bacteria×3）。

---

## 2. 当前代码结构

```text
r-analysis/
├── engine/                 # 冻结算法（Boot 旧入口仍可直调）
├── core/                   # 契约 + 子进程封装 + result_writer
├── strategies/
│   ├── strategy_registry.R
│   ├── virus/              # 生产
│   ├── bacteria/           # 生产（含 bacteria_visualization.R）
│   ├── archaea/            # stub
│   └── eukaryote/          # stub
├── metadata/               # schema + validator
├── runners/run_analysis.R  # 统一入口
├── config/analysis_config.yaml
├── input/templates/
├── test-data/{virus,bacteria}/
├── scripts/runners/run_framework_regression.R
└── docs/                   # 契约 / 审计 / 指南 / 矩阵 / 本报告
```

调用关系摘要：CLI → registry → Strategy.run → core(invoke engine) → result_writer。  
详见 [`framework_architecture_audit.md`](framework_architecture_audit.md)。

---

## 3. 已验证功能

| 功能 | 证据 |
|------|------|
| Virus 建树 + 可选环图 | 回归 `virus_valid`；H3N2 benchmark 历史产物 |
| Virus 坏 FASTA → error JSON | `virus_invalid_fasta` |
| Virus tip mismatch → error JSON | `virus_metadata_mismatch` |
| Bacteria 建树 + 三环可视化 | `bacteria_valid`；16S 任务产物 |
| Bacteria 缺 metadata 列 → error | `bacteria_invalid_metadata` |
| Bacteria tip mismatch → error（覆盖 legacy success） | `bacteria_tip_mismatch` |
| Exit 码映射 success/partial→0，error→1，not_implemented→2 | runner + 契约 |
| 必须字段含 `tree` / `error_message` / `statistics{}` | 回归形状检查 |

---

## 4. 未完成功能

| 项 | 说明 |
|----|------|
| Archaea / Eukaryote 完整 pipeline | 故意延后 |
| Spring Boot 切到 `run_analysis.R` | 本阶段禁止改 Boot |
| 前端 organism 选择 | 本阶段禁止改前端 |
| 插件式 strategy 注册（去 switch 硬编码） | Hardening 建议，未编码 |
| 共享 `fail_with_error_json` / tip 校验抽取 | 审计已列，未编码 |
| `align_sequences_core` 等真正委托实现 | 仍为 stop 占位 |
| 测试矩阵 fixture 全量自动化 | empty/illegal_dna/too_few 等未进六案 |
| Runner 层 error JSON 兜底 | 审计缺口 E4/E5 |
| Virus DNA / 最少序列预检与 bacteria 对齐 | 策略不对称，未改 |

---

## 5. 当前风险

| ID | 风险 | 等级 | 缓解 |
|----|------|------|------|
| R1 | 新增 organism 需改多处硬编码（OCP 部分满足） | 中 | 见接入指南；先做注册表硬化 |
| R2 | virus/bacteria `run()` 大量重复，易漂移 | 中 | 抽公共错误/tip 辅助到 core |
| R3 | virus 预检弱于 bacteria（DNA/条数） | 中 | 矩阵标 gap；产品决定是否对齐 |
| R4 | viz 失败 = partial/exit0，易被误认为“失败未退出” | 低 | 文档与矩阵标明 soft |
| R5 | 磁盘/早期 runner 失败可能无 JSON | 中 | runner 兜底（下阶段） |
| R6 | core 空契约函数给人“已实现阶段 API”错觉 | 低 | 审计已标明占位 |
| R7 | 双入口（engine CLI vs run_analysis）长期分叉 | 中 | Boot 迁移计划另立 |

**本阶段未发现**必须立刻热修的严重生产 bug；故 **未改** virus/bacteria/engine 代码。

---

## 6. 下一阶段建议

**不要**立即实现 archaea/eukaryote。

建议顺序：

1. **Hardening 编码（小步）**  
   - core：`with_analysis_error_handling`、`assert_tips_match_metadata`  
   - runner：catch 时补写 error JSON  
   - 扩展回归：bacteria empty / illegal_dna / too_few；archaea not_implemented smoke  
   - *仍避免改 virus/bacteria 业务语义；若需改 strategy 调用方式，先发变更说明*

2. **注册表去硬编码**  
   - `register_strategy` / 约定路径扫描，降低新类型触碰面  

3. **Boot 旁路接入**  
   - 新配置指向 `run_analysis.R`；DTO 读 v0.1 字段  

4. **再开新 organism**  
   - 严格按 [`new_organism_development_guide.md`](new_organism_development_guide.md)

---

## 7. Hardening 本阶段交付物清单

### 新增文件

- `docs/framework_architecture_audit.md`
- `docs/new_organism_development_guide.md`
- `docs/error_handling_audit.md`
- `docs/framework_test_matrix.md`
- `docs/framework_progress_report_v0.1.md`

### 修改文件

- （无代码修改）  
- 若需交叉链接，可选更新 `docs/multi_organism_framework.md` 相关文档节（本报告生成时可附带）

### 未触碰（按要求）

- `engine/**`
- `strategies/virus/**`
- `strategies/bacteria/**`
- Spring Boot / 前端

---

## 8. 一句话结论

v0.1 已具备 **virus + bacteria 可生产、契约可冻结、回归可重复** 的底座；扩展性受 **注册硬编码 + 编排重复** 制约。下一阶段应做 **框架硬化编码与测试扩面**，而不是新生物类型实现。
