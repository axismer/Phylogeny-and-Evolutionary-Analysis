# =============================================================================
# archaea_annotation.R — Archaea 注释配置（骨架）
# =============================================================================

ARCHAEA_EXTRA_COLUMNS <- c("taxonomy", "habitat", "temperature", "salinity")

archaea_annotation_config <- function(ctx = NULL) {
  list(
    organism_type = "archaea",
    tip_id_column = "sample_id",
    column_map = list(
      sample_id = "label",
      taxonomy = "taxonomy",
      habitat = "habitat",
      temperature = "temperature",
      salinity = "salinity"
    ),
    rings = list(
      list(field = "habitat", type = "categorical", geom = "fruit_tile"),
      list(field = "temperature", type = "continuous", geom = "fruit_tile")
    ),
    bootstrap_threshold = 70,
    status = "not_implemented"
  )
}
