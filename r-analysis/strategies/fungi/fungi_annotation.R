# =============================================================================
# fungi_annotation.R — Fungi ITS 注释配置与 metadata 映射
#
# 环：taxonomy / host（不复制 bacteria 的 environment/resistance 模型）
# =============================================================================

FUNGI_EXTRA_COLUMNS <- c(
  "taxonomy", "host", "substrate", "location", "collection_date"
)

FUNGI_REQUIRED_META_COLUMNS <- c(
  "sample_id", "organism_type", "taxonomy", "host", "substrate",
  "location", "collection_date"
)

#' Fungi annotation 配置（两环：taxonomy / host）
fungi_annotation_config <- function(ctx = NULL) {
  list(
    organism_type = "fungi",
    tip_id_column = "sample_id",
    marker = "ITS",
    column_map = list(
      sample_id = "label",
      taxonomy = "taxonomy",
      host = "host",
      substrate = "substrate",
      location = "location",
      collection_date = "collection_date"
    ),
    rings = list(
      list(field = "taxonomy", type = "categorical", geom = "fruit_tile", role = "taxonomy"),
      list(field = "host", type = "categorical", geom = "fruit_tile", role = "host")
    ),
    bootstrap_threshold = 70,
    viz_script = "strategies/fungi/fungi_visualization.R",
    status = "ready"
  )
}

#' 统一 schema → 可视化列（label + taxonomy + host）；tip 用 label=sample_id
map_fungi_metadata_for_viz <- function(meta) {
  out <- meta
  if ("sample_id" %in% names(out) && !"label" %in% names(out)) {
    out$label <- as.character(out$sample_id)
  }
  for (col in c("taxonomy", "host", "substrate", "location", "collection_date", "label")) {
    if (col %in% names(out)) {
      out[[col]] <- as.character(out[[col]])
      out[[col]][is.na(out[[col]]) | !nzchar(out[[col]])] <- "unknown"
    }
  }
  out
}

#' 严格检查 fungi metadata 必需列
assert_fungi_metadata_columns <- function(meta) {
  missing <- setdiff(FUNGI_REQUIRED_META_COLUMNS, names(meta))
  if (length(missing) > 0) {
    raise_framework_error(
      "MISSING_METADATA_FIELDS",
      paste0("Fungi metadata 缺少必需列: ", paste(missing, collapse = ", "))
    )
  }
  invisible(meta)
}
