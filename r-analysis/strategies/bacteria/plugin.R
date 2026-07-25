# =============================================================================
# bacteria/plugin.R — Bacteria organism plugin（包装既有 bacteria_strategy）
# =============================================================================

get_organism_type <- function() {
  "bacteria"
}

get_status <- function() {
  "production"
}

get_metadata_schema <- function() {
  list(
    organism_type = "bacteria",
    extra_columns = c("taxonomy", "environment", "source", "resistance"),
    required_core = c("sample_id", "organism_type"),
    shared_optional = c("collection_date", "location", "host"),
    strict_default = TRUE
  )
}

get_default_config <- function() {
  list(
    tree = list(
      method = "Maximum Likelihood",
      model = "JC69",
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = "engine/phylogenetic_tree.R",
      status = "production_via_legacy_engine"
    ),
    distance = list(model = "K80", pairwise_deletion = TRUE),
    visualization = list(
      layout = "circular",
      legacy_script = "strategies/bacteria/bacteria_visualization.R",
      taxonomy_level = "taxonomy",
      ring_fields = c("taxonomy", "environment", "resistance"),
      bootstrap_threshold = 70,
      status = "production_via_legacy_engine"
    )
  )
}

get_strategy <- function() {
  dirs <- .get_framework_dirs()
  sf <- file.path(dirs$strategies, "bacteria", "bacteria_strategy.R")
  if (!exists("create_bacteria_strategy", mode = "function")) {
    if (!file.exists(sf)) {
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0("bacteria plugin: strategy 文件不存在: ", sf)
      )
    }
    source(sf, local = FALSE)
  }
  if (!exists("create_bacteria_strategy", mode = "function")) {
    raise_framework_error(
      "PLUGIN_LOAD_FAILED",
      "bacteria plugin: 未找到 create_bacteria_strategy()"
    )
  }
  create_bacteria_strategy()
}
