# =============================================================================
# bacteria_annotation.R — Bacteria 注释配置与 metadata 映射
#
# taxonomy_level：从配置选择环 1 所用分类列；不实现任何分类鉴定算法。
#
# 默认行为（无配置 / 非法值）：环 1 = legacy 列 `taxonomy`。
# 配置例：strategies.bacteria.taxonomy_level: genus
# 若 metadata 无对应层级列 → 回退 `taxonomy`（旧表兼容）。
# =============================================================================

BACTERIA_EXTRA_COLUMNS <- c("taxonomy", "environment", "source", "resistance")

# 可选层级列（不强制；用户自备，框架不推断、不跑分类）
BACTERIA_TAXONOMY_RANK_COLUMNS <- c(
  "phylum", "class", "order", "family", "genus", "species"
)

BACTERIA_TAXONOMY_LEVELS <- c(BACTERIA_TAXONOMY_RANK_COLUMNS, "taxonomy")

BACTERIA_REQUIRED_META_COLUMNS <- c(
  "sample_id", "taxonomy", "environment", "source", "resistance"
)

# 代码缺省 = taxonomy（保持现有 annotation 默认行为）
# 项目推荐值写在 config/analysis_config.yaml（taxonomy_level: genus）
BACTERIA_DEFAULT_TAXONOMY_LEVEL <- "taxonomy"

#' 从 ctx / 配置读取 taxonomy_level（缺省 taxonomy；非法值回退 taxonomy）
resolve_bacteria_taxonomy_level <- function(ctx = NULL, taxonomy_level = NULL) {
  lvl <- taxonomy_level
  if (is.null(lvl) || !nzchar(as.character(lvl)[[1]])) {
    cfg <- NULL
    if (!is.null(ctx) && is.list(ctx$config)) {
      cfg <- ctx$config$strategies$bacteria$taxonomy_level
      if (is.null(cfg) && is.list(ctx$config$strategies$bacteria$annotation)) {
        cfg <- ctx$config$strategies$bacteria$annotation$taxonomy_level
      }
    }
    lvl <- cfg
  }
  if (is.null(lvl) || !nzchar(as.character(lvl)[[1]])) {
    lvl <- BACTERIA_DEFAULT_TAXONOMY_LEVEL
  }
  lvl <- tolower(trimws(as.character(lvl)[[1]]))
  if (!lvl %in% BACTERIA_TAXONOMY_LEVELS) {
    warning(
      "BacteriaStrategy: 未知 taxonomy_level='", lvl,
      "'；允许: ", paste(BACTERIA_TAXONOMY_LEVELS, collapse = ", "),
      "。回退为 ", BACTERIA_DEFAULT_TAXONOMY_LEVEL, ".",
      call. = FALSE
    )
    lvl <- BACTERIA_DEFAULT_TAXONOMY_LEVEL
  }
  lvl
}

#' 按 taxonomy_level 选择环图字段；缺列时回退 legacy `taxonomy`
#'
#' - taxonomy_level=taxonomy → 始终用 taxonomy
#' - taxonomy_level=genus（等）且列存在 → 用该列
#' - 列不存在但有 taxonomy → 回退 taxonomy（旧 metadata 兼容）
resolve_taxonomy_ring_field <- function(meta, taxonomy_level = BACTERIA_DEFAULT_TAXONOMY_LEVEL) {
  level <- resolve_bacteria_taxonomy_level(taxonomy_level = taxonomy_level)
  cols <- names(meta)
  if (identical(level, "taxonomy")) {
    if (!"taxonomy" %in% cols) {
      stop("metadata 缺少 taxonomy 列", call. = FALSE)
    }
    return(list(
      requested = level,
      field = "taxonomy",
      fallback = FALSE
    ))
  }
  if (level %in% cols) {
    return(list(
      requested = level,
      field = level,
      fallback = FALSE
    ))
  }
  if ("taxonomy" %in% cols) {
    message(
      "[bacteria] taxonomy_level=", level,
      " 列不存在；回退使用 legacy 列 taxonomy（兼容旧 metadata）"
    )
    return(list(
      requested = level,
      field = "taxonomy",
      fallback = TRUE
    ))
  }
  stop(
    "metadata 需要列 '", level, "' 或兼容列 'taxonomy'",
    call. = FALSE
  )
}

#' Bacteria annotation 配置（三环：taxonomy_level 所选列 / environment / resistance）
bacteria_annotation_config <- function(ctx = NULL) {
  level <- resolve_bacteria_taxonomy_level(ctx)
  list(
    organism_type = "bacteria",
    tip_id_column = "sample_id",
    taxonomy_level = level,
    taxonomy_rank_columns = BACTERIA_TAXONOMY_RANK_COLUMNS,
    column_map = list(
      sample_id = "label",
      taxonomy = "taxonomy",
      environment = "environment",
      source = "source",
      resistance = "resistance"
    ),
    # rings[[1]]$field = 配置偏好；实际列在 map/viz 时 resolve（可回退 taxonomy）
    rings = list(
      list(field = level, type = "categorical", geom = "fruit_tile", role = "taxonomy"),
      list(field = "environment", type = "categorical", geom = "fruit_tile"),
      list(field = "resistance", type = "categorical", geom = "fruit_tile")
    ),
    bootstrap_threshold = 70,
    viz_script = "strategies/bacteria/bacteria_visualization.R",
    status = "ready"
  )
}

#' 统一 schema → 可视化所需列（label + 环字段 + 可选层级列）
#'
#' @param taxonomy_level 配置偏好；缺省 taxonomy
#' @return data.frame；attr(*, "taxonomy_ring_field") 为实际环 1 列名
map_bacteria_metadata_for_viz <- function(meta, taxonomy_level = BACTERIA_DEFAULT_TAXONOMY_LEVEL) {
  out <- meta
  if ("sample_id" %in% names(out) && !"label" %in% names(out)) {
    out$label <- as.character(out$sample_id)
  }

  rank_cols <- intersect(BACTERIA_TAXONOMY_RANK_COLUMNS, names(out))
  fill_cols <- unique(c("taxonomy", "environment", "source", "resistance", "label", rank_cols))
  for (col in fill_cols) {
    if (col %in% names(out)) {
      out[[col]] <- as.character(out[[col]])
      out[[col]][is.na(out[[col]]) | !nzchar(out[[col]])] <- "unknown"
    }
  }

  resolved <- resolve_taxonomy_ring_field(out, taxonomy_level = taxonomy_level)
  attr(out, "taxonomy_level") <- resolved$requested
  attr(out, "taxonomy_ring_field") <- resolved$field
  attr(out, "taxonomy_ring_fallback") <- resolved$fallback
  out
}

#' 严格检查细菌 metadata 必需列（层级列可选，保持旧表兼容）
assert_bacteria_metadata_columns <- function(meta) {
  missing <- setdiff(BACTERIA_REQUIRED_META_COLUMNS, names(meta))
  if (length(missing) > 0) {
    stop(
      "Bacteria metadata 缺少必需列: ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(meta)
}
