# =============================================================================
# virus_annotation.R — Virus 可视化 / metadata 字段映射
#
# 现有 H3N2 circular 契约：label, Country, Year（可选 Host）
# 统一 schema 字段 → 旧可视化列名的适配在此完成。
# =============================================================================

#' Virus 扩展 metadata 列
VIRUS_EXTRA_COLUMNS <- c("segment", "variant")

#' Virus annotation 配置（供 ggtree / 未来统一 viz）
virus_annotation_config <- function(ctx = NULL) {
  list(
    organism_type = "virus",
    tip_id_column = "sample_id",
    # 统一 schema → 现有 ggtree 脚本列名
    column_map = list(
      sample_id = "label",
      location = "Country",
      collection_date = "Year",  # 过渡：日期取年；完整日期后续增强
      host = "Host",
      segment = "segment",
      variant = "variant"
    ),
    rings = list(
      list(field = "Country", type = "categorical", geom = "fruit_tile"),
      list(field = "Year", type = "ordinal", geom = "fruit_tile")
    ),
    bootstrap_threshold = 70,
    legacy_viz_script = "engine/ggtree_visualization.R",
    notes = paste(
      "当前生产路径仍调用 engine/ggtree_visualization.R；",
      "若 metadata 已是 label/Country/Year，可直接传入；",
      "若为统一 schema（sample_id/location/...），先经 map_virus_metadata_for_legacy_viz()。"
    )
  )
}

#' 将统一 schema metadata 映射为现有 ggtree 所需列
#'
#' @param meta data.frame
#' @return data.frame 含 label, Country, Year, Host（若可得）
map_virus_metadata_for_legacy_viz <- function(meta) {
  out <- meta
  if ("sample_id" %in% names(out) && !"label" %in% names(out)) {
    out$label <- out$sample_id
  }
  if ("location" %in% names(out) && !"Country" %in% names(out)) {
    out$Country <- out$location
  }
  if ("collection_date" %in% names(out) && !"Year" %in% names(out)) {
    # 允许 YYYY / YYYY-MM-DD；取前 4 位作年
    out$Year <- substr(as.character(out$collection_date), 1, 4)
  }
  if ("host" %in% names(out) && !"Host" %in% names(out)) {
    out$Host <- out$host
  }
  out
}
