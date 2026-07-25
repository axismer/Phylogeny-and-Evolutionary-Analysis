# =============================================================================
# virus/plugin.R — Virus organism plugin（包装既有 virus_strategy，不改 run 流程）
# =============================================================================

get_organism_type <- function() {
  "virus"
}

get_status <- function() {
  "production"
}

get_metadata_schema <- function() {
  list(
    organism_type = "virus",
    extra_columns = c("segment", "variant"),
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
      legacy_engine = "engine/phylogenetic_tree.R"
    ),
    distance = list(model = "K80", pairwise_deletion = TRUE),
    visualization = list(
      layout = "circular",
      legacy_script = "engine/ggtree_visualization.R",
      ring_fields = c("Country", "Year"),
      bootstrap_threshold = 70
    )
  )
}

get_strategy <- function() {
  dirs <- .get_framework_dirs()
  sf <- file.path(dirs$strategies, "virus", "virus_strategy.R")
  if (!exists("create_virus_strategy", mode = "function")) {
    if (!file.exists(sf)) {
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0("virus plugin: strategy 文件不存在: ", sf)
      )
    }
    source(sf, local = FALSE)
  }
  if (!exists("create_virus_strategy", mode = "function")) {
    raise_framework_error(
      "PLUGIN_LOAD_FAILED",
      "virus plugin: 未找到 create_virus_strategy()"
    )
  }
  create_virus_strategy()
}
