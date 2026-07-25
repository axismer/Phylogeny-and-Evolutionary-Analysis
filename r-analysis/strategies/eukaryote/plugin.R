# =============================================================================
# eukaryote/plugin.R — Eukaryote stub plugin（不实现 pipeline）
# =============================================================================

get_organism_type <- function() {
  "eukaryote"
}

get_status <- function() {
  "stub"
}

get_metadata_schema <- function() {
  list(
    organism_type = "eukaryote",
    extra_columns = c("taxonomy", "location", "host", "life_stage"),
    required_core = c("sample_id", "organism_type"),
    shared_optional = c("collection_date", "location", "host"),
    strict_default = FALSE
  )
}

get_default_config <- function() {
  list(
    tree = list(
      method = "Maximum Likelihood",
      model = "JC69",
      start_tree = "NJ",
      bootstrap = TRUE,
      legacy_engine = NULL,
      status = "not_implemented"
    ),
    distance = list(model = "K80", pairwise_deletion = TRUE),
    visualization = list(
      layout = "circular",
      legacy_script = NULL,
      ring_fields = c("taxonomy", "life_stage"),
      bootstrap_threshold = 70,
      status = "not_implemented"
    )
  )
}

get_strategy <- function() {
  dirs <- .get_framework_dirs()
  sf <- file.path(dirs$strategies, "eukaryote", "eukaryote_strategy.R")
  if (!exists("create_eukaryote_strategy", mode = "function")) {
    if (!file.exists(sf)) {
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0("eukaryote plugin: strategy 文件不存在: ", sf)
      )
    }
    source(sf, local = FALSE)
  }
  if (!exists("create_eukaryote_strategy", mode = "function")) {
    raise_framework_error(
      "PLUGIN_LOAD_FAILED",
      "eukaryote plugin: 未找到 create_eukaryote_strategy()"
    )
  }
  create_eukaryote_strategy()
}
