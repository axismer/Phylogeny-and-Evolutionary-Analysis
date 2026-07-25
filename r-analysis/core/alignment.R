# =============================================================================
# alignment.R — 比对阶段公共接口（薄封装）
#
# 当前阶段：定义统一函数签名，委托现有 engine/phylogenetic_tree.R 中的
# align_sequences()（不修改该算法）。完整 bacteria/archaea 比对策略后续实现。
# =============================================================================

#' 解析 r-analysis 根目录
resolve_r_analysis_root <- function(script_dir = NULL) {
  if (is.null(script_dir)) {
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      script_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1])))
    } else {
      script_dir <- normalizePath(getwd())
    }
  }
  # core/ 或 runners/ 均位于 r-analysis 下一层
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = FALSE)
}

#' 加载现有建树引擎（只 source，不改算法）
load_legacy_tree_engine <- function(r_root = NULL) {
  if (is.null(r_root)) {
    r_root <- resolve_r_analysis_root()
  }
  engine_path <- file.path(r_root, "engine", "phylogenetic_tree.R")
  if (!file.exists(engine_path)) {
    stop("找不到现有建树引擎: ", engine_path, call. = FALSE)
  }
  # phylogenetic_tree.R 在 source 时若作为 CLI 主脚本会解析参数；
  # 作为库加载时需避免执行 main。当前文件在直接 Rscript 时才跑 main。
  # 过渡期：Strategy 通过 system2(Rscript, ...) 调用 CLI，或后续抽出函数库。
  list(engine_path = engine_path, r_root = r_root)
}

#' 比对接口（契约）
#'
#' @param sequences 序列对象（DNAbin / AAbin / 路径，由 Strategy 约定）
#' @param params list，含 aligner, molecule_type, ...
#' @return 比对后序列（类型由 Strategy 约定）
#'
#' @note Virus 现状：等长跳过 / MAFFT / MUSCLE / gap 回退（见 engine）
#'       Bacteria 预留：多拷贝 16S / 全基因组 marker 等（未实现）
align_sequences_core <- function(sequences, params = list()) {
  stop(
    "align_sequences_core(): 过渡期请通过 Strategy$run() 调用 ",
    "engine/phylogenetic_tree.R 的既有比对逻辑；",
    "本函数待算法抽出后再填充。",
    call. = FALSE
  )
}
