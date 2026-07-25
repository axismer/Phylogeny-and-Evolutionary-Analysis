# =============================================================================
# distance.R — 遗传距离计算公共接口
#
# 现有 Virus pipeline：K80 → distance_matrix.csv（engine/phylogenetic_tree.R）
# 本文件仅定义统一签名与默认参数约定，不复制算法。
# =============================================================================

#' 默认距离参数（可被 Strategy$tree_params() 覆盖）
#' P3：优先 plugin get_default_config()$distance。
#'
#' @section Deprecated fallback:
#' 下方 `switch` 为 **deprecated fallback**（P4 禁止删除）。见 docs/deprecated_components.md。
default_distance_params <- function(organism_type = "virus") {
  organism_type <- tolower(organism_type)
  if (exists("lookup_plugin_default_config", mode = "function")) {
    cfg <- lookup_plugin_default_config(organism_type)
    if (is.list(cfg) && is.list(cfg$distance) && length(cfg$distance) > 0) {
      return(cfg$distance)
    }
  }
  switch(
    organism_type,
    virus = list(model = "K80", pairwise_deletion = TRUE),
    # 细菌常用：16S 常用 K80/TN93；后续可接 dist.dna / 专用距离
    bacteria = list(model = "K80", pairwise_deletion = TRUE),
    archaea = list(model = "K80", pairwise_deletion = TRUE),
    eukaryote = list(model = "K80", pairwise_deletion = TRUE),
    stop("未知 organism_type: ", organism_type, call. = FALSE)
  )
}

#' 距离计算接口（契约）
#'
#' @param aligned 比对后序列
#' @param params list(model, ...)
#' @return 距离矩阵（dist 或 matrix）
calculate_distance_core <- function(aligned, params = list()) {
  stop(
    "calculate_distance_core(): 过渡期委托 engine/phylogenetic_tree.R::calculate_distance()；",
    "本函数待抽出后再填充。",
    call. = FALSE
  )
}
