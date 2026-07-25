# =============================================================================
# fungi/plugin.R — Fungi organism plugin（ITS DNA；production）
# =============================================================================

get_organism_type <- function() {
  "fungi"
}

get_status <- function() {
  "production"
}

get_metadata_schema <- function() {
  list(
    organism_type = "fungi",
    extra_columns = c("taxonomy", "host", "substrate", "location", "collection_date"),
    required_core = c("sample_id", "organism_type"),
    shared_optional = character(0),
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
      marker = "ITS",
      status = "production_via_legacy_engine"
    ),
    distance = list(model = "K80", pairwise_deletion = TRUE),
    visualization = list(
      layout = "circular",
      legacy_script = "strategies/fungi/fungi_visualization.R",
      ring_fields = c("taxonomy", "host"),
      bootstrap_threshold = 70,
      status = "production"
    )
  )
}

get_strategy <- function() {
  dirs <- .get_framework_dirs()
  sf <- file.path(dirs$strategies, "fungi", "fungi_strategy.R")
  if (!exists("create_fungi_strategy", mode = "function")) {
    if (!file.exists(sf)) {
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0("fungi plugin: strategy 文件不存在: ", sf)
      )
    }
    source(sf, local = FALSE)
  }
  if (!exists("create_fungi_strategy", mode = "function")) {
    raise_framework_error(
      "PLUGIN_LOAD_FAILED",
      "fungi plugin: 未找到 create_fungi_strategy()"
    )
  }
  create_fungi_strategy()
}
