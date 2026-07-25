# =============================================================================
# strategy_base.R — PhyloAnalysisStrategy 统一接口（Strategy Pattern）
#
# 本文件只定义契约与工厂辅助，不实现具体生物类型 pipeline。
# 现有 engine/phylogenetic_tree.R / ggtree_visualization.R 保持不变；
# Strategy 通过 core/* 薄封装调用它们，或后续替换为专用实现。
# =============================================================================

#' 支持的 organism_type 取值（文档 / **deprecated fallback** 兼容表）
#'
#' P3 起新类型以 `strategies/*/plugin.R` 注册为准，不必改此常量。
#' P4：禁止删除本表。见 docs/deprecated_components.md。
PHYLO_ORGANISM_TYPES <- c("virus", "bacteria", "archaea", "eukaryote")

#' 创建一个 Strategy 对象（R list + class 标记）
#'
#' 必填方法（函数槽位）：
#'   validate_input(ctx)       — 检查 FASTA / 序列数 / 分子类型约定
#'   parse_metadata(ctx)       — 读取并规范化 metadata.csv
#'   tree_params(ctx)          — 返回建树参数 list（model, method, ...）
#'   annotation_config(ctx)    — 返回可视化 annotation 配置
#'   output_spec(ctx)          — 返回期望输出文件名约定
#'   run(ctx)                  — 编排完整分析（可调用 core/*）
#'
#' @param organism_type character；优先已注册 plugin，其次 PHYLO_ORGANISM_TYPES
#' @param ... 方法实现与可选字段
#' @return 带 class "PhyloAnalysisStrategy" 的 list
new_phylo_strategy <- function(organism_type, ...) {
  organism_type <- tolower(organism_type)
  if (!nzchar(organism_type)) {
    stop("organism_type 不能为空", call. = FALSE)
  }
  allowed <- PHYLO_ORGANISM_TYPES
  if (exists("list_registered_strategies", mode = "function")) {
    reg <- tryCatch(list_registered_strategies(), error = function(...) character())
    allowed <- unique(c(allowed, reg))
  }
  # P3：允许已注册 plugin 类型；未列入常量的新类型只要已注册即可
  if (!organism_type %in% allowed) {
    # 仍允许构造（plugin 扩展）；仅警告，避免新类型必须改 core
    warning(
      "organism_type 不在 PHYLO_ORGANISM_TYPES/已注册表: ", organism_type,
      "；继续创建 Strategy（plugin 扩展路径）",
      call. = FALSE
    )
  }

  strategy <- list(
    organism_type = organism_type,
    validate_input = function(ctx) {
      stop("validate_input() 未实现: ", organism_type, call. = FALSE)
    },
    parse_metadata = function(ctx) {
      stop("parse_metadata() 未实现: ", organism_type, call. = FALSE)
    },
    tree_params = function(ctx) {
      stop("tree_params() 未实现: ", organism_type, call. = FALSE)
    },
    annotation_config = function(ctx) {
      stop("annotation_config() 未实现: ", organism_type, call. = FALSE)
    },
    output_spec = function(ctx) {
      default_output_spec(organism_type)
    },
    run = function(ctx) {
      stop("run() 未实现: ", organism_type, call. = FALSE)
    }
  )

  overrides <- list(...)
  for (nm in names(overrides)) {
    strategy[[nm]] <- overrides[[nm]]
  }

  class(strategy) <- c(
    paste0(tools::toTitleCase(organism_type), "PhyloStrategy"),
    "PhyloAnalysisStrategy",
    "list"
  )
  strategy
}

#' 分析上下文：CLI / Spring Boot 传入的统一运行时对象
#'
#' @param organism_type virus|bacteria|archaea|eukaryote
#' @param fasta_path 输入 FASTA
#' @param metadata_path 输入 metadata.csv（可空，部分类型后续强制）
#' @param output_dir 输出目录
#' @param config 解析后的 analysis_config.yaml（list）
#' @param extras 可选扩展参数
new_analysis_context <- function(organism_type,
                                 fasta_path,
                                 metadata_path = NULL,
                                 output_dir,
                                 config = list(),
                                 extras = list()) {
  list(
    organism_type = tolower(organism_type),
    fasta_path = fasta_path,
    metadata_path = metadata_path,
    output_dir = output_dir,
    config = config,
    extras = extras,
    started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

#' 统一输出文件约定（各 Strategy 可覆盖文件名，但字段键保持稳定）
default_output_spec <- function(organism_type) {
  list(
    organism_type = organism_type,
    tree_file = "tree.nwk",
    distance_matrix = "distance_matrix.csv",
    tree_image = "tree.png",
    visualization = "circular_tree_final.png",
    visualization_pdf = "circular_tree_final.pdf",
    metadata = "metadata.csv",
    result_json = "analysis_result.json",
    visualization_report = "visualization_report.json"
  )
}

#' 断言对象实现了 Strategy 契约
assert_phylo_strategy <- function(strategy) {
  if (!inherits(strategy, "PhyloAnalysisStrategy")) {
    stop("对象不是 PhyloAnalysisStrategy", call. = FALSE)
  }
  required <- c(
    "organism_type", "validate_input", "parse_metadata",
    "tree_params", "annotation_config", "output_spec", "run"
  )
  missing <- setdiff(required, names(strategy))
  if (length(missing) > 0) {
    stop("Strategy 缺少字段: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}
