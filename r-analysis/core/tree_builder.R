# =============================================================================
# tree_builder.R — 建树公共接口
#
# 重要：不修改 engine/phylogenetic_tree.R 中的 ML(JC69) 实现。
# Virus 策略继续调用该脚本；其他类型通过 tree_params 声明参数，后续实现。
# =============================================================================

#' 默认建树参数
#'
#' Virus 当前冻结行为：NJ 起始 + Maximum Likelihood / JC69
#' P3：优先 plugin get_default_config()$tree。
#'
#' @section Deprecated fallback:
#' 下方 `switch` 为 **deprecated fallback**（P4 禁止删除）。
#' 无 plugin / 早期加载时仍服务四类型。未来仅在 audit 证明 plugin≡switch 后清理。
#' 见 docs/deprecated_components.md。
default_tree_params <- function(organism_type = "virus") {
  organism_type <- tolower(organism_type)
  if (exists("lookup_plugin_default_config", mode = "function")) {
    cfg <- lookup_plugin_default_config(organism_type)
    if (is.list(cfg) && is.list(cfg$tree) && length(cfg$tree) > 0) {
      return(cfg$tree)
    }
  }
  switch(
    organism_type,
    virus = list(
      method = "Maximum Likelihood",
      model = "JC69",
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = "engine/phylogenetic_tree.R"
    ),
    bacteria = list(
      method = "Maximum Likelihood",
      model = "JC69",           # 第一版复用冻结引擎；后续可改为 GTR / 16S 专用
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = "engine/phylogenetic_tree.R",
      status = "production_via_legacy_engine"
    ),
    archaea = list(
      method = "Maximum Likelihood",
      model = "JC69",
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = NULL,
      status = "not_implemented"
    ),
    eukaryote = list(
      method = "Maximum Likelihood",
      model = "JC69",
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = NULL,
      status = "not_implemented"
    ),
    stop("未知 organism_type: ", organism_type, call. = FALSE)
  )
}

#' 建树接口（契约）
#'
#' @param distance_or_aligned 距离矩阵或比对对象
#' @param params list(method, model, ...)
#' @return phylo 对象
build_tree_core <- function(distance_or_aligned, params = list()) {
  stop(
    "build_tree_core(): 过渡期委托 engine/phylogenetic_tree.R::build_tree()；",
    "禁止在本层复制/改写 JC69 算法。",
    call. = FALSE
  )
}

#' 通过子进程调用现有 Virus 建树 CLI（保持算法冻结）
#'
#' @param fasta_path 输入 FASTA
#' @param output_dir 输出目录
#' @param rscript Rscript 可执行文件
#' @param r_root r-analysis 根目录
#' @return list(exit_code, engine_path, output_dir)
invoke_legacy_tree_engine <- function(fasta_path,
                                      output_dir,
                                      rscript = "Rscript",
                                      r_root = NULL) {
  info <- load_legacy_tree_engine(r_root)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  exit_code <- system2(
    rscript,
    args = c(shQuote(info$engine_path), shQuote(fasta_path), shQuote(output_dir)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(exit_code, "status")
  if (is.null(status)) status <- 0L
  list(
    exit_code = as.integer(status),
    engine_path = info$engine_path,
    output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
    log = exit_code
  )
}
