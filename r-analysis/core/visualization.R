# =============================================================================
# visualization.R — 可视化公共接口
#
# 现有 Virus circular：engine/ggtree_visualization.R（不修改）
# Strategy 通过 annotation_config() 声明环图字段，再调用本层编排。
# =============================================================================

#' 默认可视化参数
#' P3：优先 plugin get_default_config()$visualization。
#'
#' @section Deprecated fallback:
#' 下方 `switch` 为 **deprecated fallback**（P4 禁止删除）。见 docs/deprecated_components.md。
default_viz_params <- function(organism_type = "virus") {
  organism_type <- tolower(organism_type)
  if (exists("lookup_plugin_default_config", mode = "function")) {
    cfg <- lookup_plugin_default_config(organism_type)
    if (is.list(cfg) && is.list(cfg$visualization) && length(cfg$visualization) > 0) {
      return(cfg$visualization)
    }
  }
  switch(
    organism_type,
    virus = list(
      layout = "circular",
      legacy_script = "engine/ggtree_visualization.R",
      # 现有契约列：label, Country, Year（兼容 Phylum/Age）
      ring_fields = c("Country", "Year"),
      bootstrap_threshold = 70
    ),
    bacteria = list(
      layout = "circular",
      legacy_script = "strategies/bacteria/bacteria_visualization.R",
      # 代码缺省 taxonomy；yaml strategies.bacteria.taxonomy_level 可覆盖（如 genus）
      # 环 1 实际列由 taxonomy_level 解析；缺列时回退 taxonomy
      taxonomy_level = "taxonomy",
      ring_fields = c("taxonomy", "environment", "resistance"),
      bootstrap_threshold = 70,
      status = "production_via_legacy_engine"
    ),
    archaea = list(
      layout = "circular",
      legacy_script = NULL,
      ring_fields = c("habitat", "temperature"),
      bootstrap_threshold = 70,
      status = "not_implemented"
    ),
    eukaryote = list(
      layout = "circular",
      legacy_script = NULL,
      ring_fields = c("taxonomy", "life_stage"),
      bootstrap_threshold = 70,
      status = "not_implemented"
    ),
    stop("未知 organism_type: ", organism_type, call. = FALSE)
  )
}

#' 可视化接口（契约）
render_tree_visualization_core <- function(tree_path,
                                           metadata_path,
                                           output_dir,
                                           annotation = list()) {
  stop(
    "render_tree_visualization_core(): 过渡期委托 engine/ggtree_visualization.R；",
    "本函数待统一 annotation 适配层后再填充。",
    call. = FALSE
  )
}

#' 调用现有 ggtree circular CLI（Virus 路径）
invoke_legacy_ggtree_viz <- function(tree_path,
                                     metadata_path,
                                     output_dir,
                                     rscript = "Rscript",
                                     r_root = NULL) {
  if (is.null(r_root)) {
    r_root <- resolve_r_analysis_root()
  }
  script <- file.path(r_root, "engine", "ggtree_visualization.R")
  if (!file.exists(script)) {
    stop("找不到可视化脚本: ", script, call. = FALSE)
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  exit_code <- system2(
    rscript,
    args = c(
      shQuote(script),
      shQuote(tree_path),
      shQuote(metadata_path),
      shQuote(output_dir)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(exit_code, "status")
  if (is.null(status)) status <- 0L
  list(
    exit_code = as.integer(status),
    script = script,
    output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
    log = exit_code
  )
}
