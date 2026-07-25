# =============================================================================
# eukaryote_annotation.R — Eukaryote 注释配置（骨架）
# =============================================================================

EUKARYOTE_EXTRA_COLUMNS <- c("taxonomy", "location", "host", "life_stage")

eukaryote_annotation_config <- function(ctx = NULL) {
  list(
    organism_type = "eukaryote",
    tip_id_column = "sample_id",
    # location / host 与公共字段同名；扩展侧重 life_stage / taxonomy
    column_map = list(
      sample_id = "label",
      taxonomy = "taxonomy",
      location = "location",
      host = "host",
      life_stage = "life_stage",
      collection_date = "collection_date"
    ),
    rings = list(
      list(field = "taxonomy", type = "categorical", geom = "fruit_tile"),
      list(field = "life_stage", type = "categorical", geom = "fruit_tile")
    ),
    bootstrap_threshold = 70,
    status = "not_implemented"
  )
}
